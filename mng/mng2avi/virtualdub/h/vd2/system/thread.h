//	VirtualDub - Video processing and capture application
//	System library component
//	Copyright (C) 1998-2004 Avery Lee, All Rights Reserved.
//
//	Beginning with 1.6.0, the VirtualDub system library is licensed
//	differently than the remainder of VirtualDub.  This particular file is
//	thus licensed as follows (the "zlib" license):
//
//	This software is provided 'as-is', without any express or implied
//	warranty.  In no event will the authors be held liable for any
//	damages arising from the use of this software.
//
//	Permission is granted to anyone to use this software for any purpose,
//	including commercial applications, and to alter it and redistribute it
//	freely, subject to the following restrictions:
//
//	1.	The origin of this software must not be misrepresented; you must
//		not claim that you wrote the original software. If you use this
//		software in a product, an acknowledgment in the product
//		documentation would be appreciated but is not required.
//	2.	Altered source versions must be plainly marked as such, and must
//		not be misrepresented as being the original software.
//	3.	This notice may not be removed or altered from any source
//		distribution.

#ifndef f_VD2_SYSTEM_THREAD_H
#define f_VD2_SYSTEM_THREAD_H

#include <windows.h>

#include <vd2/system/atomic.h>

typedef void *VDThreadHandle;
typedef unsigned VDThreadID;

VDThreadID VDGetCurrentThreadID();

void VDSetThreadDebugName(VDThreadID tid, const char *name);

///////////////////////////////////////////////////////////////////////////
//
//	VDThread
//
//	VDThread is a quick way to portably create threads -- to use it,
//	derive a subclass from it that implements the ThreadRun() function.
//
//	Win32 notes:
//
//	The thread startup code will attempt to notify the VC++ debugger of
//	the debug name of the thread.  Only the first 9 characters are used
//	by Visual C 6.0; Visual Studio .NET will accept a few dozen.
//
//	VDThread objects must not be WaitThread()ed or destructed from a
//	DllMain() function, TLS callback for an executable, or static
//	destructor unless the thread has been detached from the object.
//  The reason is that Win32 serializes calls to DllMain() functions.
//  If you attempt to do so, you will cause a deadlock when Win32
//  attempts to fire thread detach notifications.
//
///////////////////////////////////////////////////////////////////////////

class VDThread {
public:
	VDThread(const char *pszDebugName = NULL);	// NOTE: pszDebugName must have static duration
	~VDThread() throw();

	// external functions

	bool ThreadStart();							// start thread
	void ThreadDetach();						// detach thread (wait() won't be called)
	void ThreadWait();							// wait for thread to finish

	bool isThreadActive();

	bool isThreadAttached() const {				// NOTE: Will return true if thread started, even if thread has since exited
		return mhThread != 0;
	}

	VDThreadHandle getThreadHandle() const {	// get handle to thread (Win32: HANDLE)
		return mhThread;
	}

	VDThreadID getThreadID() const {			// get ID of thread (Win32: DWORD)
		return mThreadID;
	}

	void *ThreadLocation() const;				// retrieve current EIP of thread (use only for debug purposes -- may not return reliable information on syscall, etc.)

	// thread-local functions

	virtual void ThreadRun() = 0;				// thread, come to life
	void ThreadFinish();						// exit thread

private:
	static unsigned __stdcall StaticThreadStart(void *pThis);

	const char *mpszDebugName;
	VDThreadHandle	mhThread;
	VDThreadID		mThreadID;
};

///////////////////////////////////////////////////////////////////////////

class VDCriticalSection {
private:
	CRITICAL_SECTION csect;

	VDCriticalSection(const VDCriticalSection&);
	const VDCriticalSection& operator=(const VDCriticalSection&);
public:
	class AutoLock {
	private:
		VDCriticalSection& cs;
	public:
		AutoLock(VDCriticalSection& csect) : cs(csect) { ++cs; }
		~AutoLock() { --cs; }

		inline operator bool() const { return false; }
	};

	VDCriticalSection() {
		InitializeCriticalSection(&csect);
	}

	~VDCriticalSection() {
		DeleteCriticalSection(&csect);
	}

	void operator++() {
		EnterCriticalSection(&csect);
	}

	void operator--() {
		LeaveCriticalSection(&csect);
	}
};

// 'vdsynchronized' keyword
//
// The vdsynchronized(lock) keyword emulates Java's 'synchronized' keyword, which
// protects the following statement or block from race conditions by obtaining a
// lock during its execution:
//
//		vdsynchronized(list_lock) {
//			mList.pop_back();
//			if (mList.empty())
//				return false;
//		}
//
// The construct is exception safe and will release the lock even if a return,
// continue, break, or thrown exception exits the block.  However, hardware
// exceptions (access violations) may not work due to synchronous model
// exception handling.
//
// There are two Visual C++ bugs we need to work around here (both are in VC6 and VC7).
//
// 1) Declaring an object with a non-trivial destructor in a switch() condition
//    causes a C1001 INTERNAL COMPILER ERROR.
//
// 2) Using __LINE__ in a macro expanded in a function with Edit and Continue (/ZI)
//    breaks the preprocessor (KB article Q199057).  Shame, too, because without it
//    all the autolocks look the same.

#if defined(_MSC_VER)
#define vdsynchronized2(lock) if(VDCriticalSection::AutoLock vd__lock=(lock))VDNEVERHERE;else
#define vdsynchronized1(lock) vdsynchronized2(lock)
#define vdsynchronized(lock) vdsynchronized1(lock)
#else
#define vdsynchronized2(lock, lineno) switch(VDCriticalSection::AutoLock vd__lock##lineno=(lock))default:
#define vdsynchronized1(lock, lineno) vdsynchronized2(lock, lineno)
#define vdsynchronized(lock) vdsynchronized1(lock, __LINE__)
#endif

///////////////////////////////////////////////////////////////////////////

class VDSignalBase {
protected:
	HANDLE hEvent;

public:
	~VDSignalBase();

	void signal();
	bool check();
	void wait();
	int wait(VDSignalBase *second);
	int wait(VDSignalBase *second, VDSignalBase *third);
	HANDLE getHandle() { return hEvent; }

	void operator()() { signal(); }
};

class VDSignal : public VDSignalBase {
public:
	VDSignal();
};

class VDSignalPersistent : public VDSignalBase {
public:
	VDSignalPersistent();

	void unsignal();
};

///////////////////////////////////////////////////////////////////////////

class VDSemaphore {
	VDAtomicInt value;
	VDSignal	signalNotEmpty;

public:
	VDSemaphore(int initial) : value(initial) {}

	// I'm not using P and V.  No way.

	void operator++() {
		if (!value.postinc())
			signalNotEmpty();
	}

	void operator--() {
		while(value.postdec()<=0) {
			// Here's where it gets tricky.  Any number of threads may
			// have gotten to this point and done a down(), so the result
			// may any negative value.  What we do now is increment the
			// value back up before we block.  However, our decrementing
			// the variable may have prevented the first up() from
			// signalling.  This is indicated by a restore above zero,
			// in which case we signal instead of wait.

			if (!value.postinc()) {
				signalNotEmpty();
				continue;
			}

			signalNotEmpty.wait();
		}
	}
};

#endif
