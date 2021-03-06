#include <vd2/system/vdtypes.h>
#include <string>
#include <time.h>

#include "utils.h"

using namespace std;

void tool_verinc(bool amd64) {
	string machine_name(get_name());

	time_t systime;
	time(&systime);
	tm *ts = localtime(&systime);

	const int build = get_version();

	string build_time(asctime(ts));

	build_time.erase(build_time.size()-1);		// kill terminating newline

	static const char *const sMonths[12]={
		"January",
		"February",
		"March",
		"April",
		"May",
		"June",
		"July",
		"August",
		"September",
		"October",
		"November",
		"December"
	};

	char datestr[128];
	sprintf(datestr, "%s %d, %d", sMonths[ts->tm_mon], ts->tm_mday, 1900 + ts->tm_year);

	FILE *f = fopen("verstub.asm", "w");
	if (!f)
		fail("Unable to open verstub.asm for write.");

	if (amd64)
		fprintf(f,
			"\t"	".const\n"
			"\n"
			"\t"	"public\t"	"version_num\n"
			"\t"	"public\t"	"version_time\n"
			"\t"	"public\t"	"version_date\n"
			"\t"	"public\t"	"version_buildmachine\n"
			"\n"
			"version_num\t"	"dd\t"	"%ld\n"
			"version_time\t"	"db\t"	"\"%s\",0\n"
			"version_date\t"	"db\t"	"\"%s\",0\n"
			"version_buildmachine\t" "db\t" "\"%s\",0\n"
			"\n"
			"\t"	"end\n"
			,build
			,build_time.c_str()
			,datestr
			,machine_name.c_str());
	else
		fprintf(f,
			"\t"	".386\n"
			"\t"	".model\t"	"flat\n"
			"\t"	".const\n"
			"\n"
			"\t"	"public\t"	"_version_num\n"
			"\t"	"public\t"	"_version_time\n"
			"\t"	"public\t"	"_version_date\n"
			"\t"	"public\t"	"_version_buildmachine\n"
			"\n"
			"_version_num\t"	"dd\t"	"%ld\n"
			"_version_time\t"	"db\t"	"\"%s\",0\n"
			"_version_date\t"	"db\t"	"\"%s\",0\n"
			"_version_buildmachine\t" "db\t" "\"%s\",0\n"
			"\n"
			"\t"	"end\n"
			,build
			,build_time.c_str()
			,datestr
			,machine_name.c_str());

	fclose(f);
}
