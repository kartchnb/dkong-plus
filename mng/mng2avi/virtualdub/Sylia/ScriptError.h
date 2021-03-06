#ifndef f_SYLIA_SCRIPTERROR_H
#define f_SYLIA_SCRIPTERROR_H

class VDScriptError {
public:
	int err;

	enum {
		PARSE_ERROR=1,
		SEMICOLON_EXPECTED,
		IDENTIFIER_EXPECTED,

		TYPE_INT_REQUIRED,
		TYPE_ARRAY_REQUIRED,
		TYPE_FUNCTION_REQUIRED,
		TYPE_OBJECT_REQUIRED,

		OBJECT_MEMBER_NAME_REQUIRED,
		FUNCCALLEND_EXPECTED,
		TOO_MANY_PARAMS,
		DIVIDE_BY_ZERO,
		VAR_NOT_FOUND,
		MEMBER_NOT_FOUND,
		OVERLOADED_FUNCTION_NOT_FOUND,
		IDENT_TOO_LONG,
		OPERATOR_EXPECTED,
		CLOSEPARENS_EXPECTED,
		CLOSEBRACKET_EXPECTED,

		VAR_UNDEFINED,

		OUT_OF_STRING_SPACE,
		OUT_OF_MEMORY,
		INTERNAL_ERROR,
		EXTERNAL_ERROR,

		FCALL_OUT_OF_RANGE,
		FCALL_INVALID_PTYPE,
		FCALL_UNKNOWN_STR,

		ARRAY_INDEX_OUT_OF_BOUNDS
	};

	VDScriptError(int err_num) : err(err_num) { }

	int getErr() { return err; }
};

#define SCRIPT_ERROR(x)			throw VDScriptError(VDScriptError::##x)

const char *VDScriptTranslateError(int);

static inline const char *VDScriptTranslateError(VDScriptError cse) {
	return VDScriptTranslateError(cse.getErr());
}

#endif
