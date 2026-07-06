/*
 *  main.cpp
 *  Nuvie
 *
 *  Created by Eric Fry on Tue Mar 11 2003.
 *  Copyright (c) 2003. All rights reserved.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 *
 */

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include <time.h>
#include <cstdlib>

#include "SDL.h"

#include "nuvieDefs.h"
#include "Console.h"
#include "nuvie.h"

#include "main.h"

#ifdef MACOSX
#include <CoreFoundation/CoreFoundation.h>
#endif

#ifdef NUVIE_IOS
#include <sys/stat.h>
// Generate a ~/.nuvierc pointing at the read-only game data bundled inside the
// app (data/ and ultima6/ under Resources) and a writable save directory inside
// the app sandbox. Regenerated on every launch because the iOS container path
// can change between installs/launches.
static void nuvie_ios_setup()
{
	char resbuf[MAXPATHLEN] = "";
	CFBundleRef bundle = CFBundleGetMainBundle();
	if(bundle != NULL) {
		CFURLRef fileUrl = CFBundleCopyResourcesDirectoryURL(bundle);
		if(fileUrl) {
			CFURLGetFileSystemRepresentation(fileUrl, true, (uint8*)resbuf, sizeof(resbuf));
			CFRelease(fileUrl);
		}
	}
	const char *home = getenv("HOME");
	if(home == NULL || resbuf[0] == '\0')
		return;

	std::string res(resbuf);
	std::string docs = std::string(home) + "/Documents";
	std::string savedir = docs + "/save";
	mkdir(docs.c_str(), 0755);
	mkdir(savedir.c_str(), 0755);

	std::string cfg = std::string(home) + "/.nuvierc";
	FILE *f = fopen(cfg.c_str(), "w");
	if(f == NULL)
		return;
	fprintf(f,
		"<config>\n"
		" <loadgame>ultima6</loadgame>\n"
		" <datadir>%s/data</datadir>\n"
		" <keys>(default)</keys>\n"
		" <video>\n"
		"  <game_style>original</game_style>\n"
		"  <scale_method>Point</scale_method>\n"
		"  <scale_factor>2</scale_factor>\n"
		"  <fullscreen>yes</fullscreen>\n"
		"  <game_position>center</game_position>\n"
		" </video>\n"
		" <audio>\n"
		"  <enabled>yes</enabled>\n"
		"  <enable_music>yes</enable_music>\n"
		"  <enable_sfx>yes</enable_sfx>\n"
		"  <music_volume>100</music_volume>\n"
		"  <sfx_volume>255</sfx_volume>\n"
		" </audio>\n"
		" <general>\n"
		"  <show_console>no</show_console>\n"
		" </general>\n"
		" <ultima6>\n"
		"  <language>en</language>\n"
		"  <gamedir>%s/ultima6</gamedir>\n"
		"  <savedir>%s</savedir>\n"
		"  <sounddir>%s/data/sfx/u6</sounddir>\n"
		"  <skip_intro>no</skip_intro>\n"
		"  <music>native</music>\n"
		"  <sfx>native</sfx>\n"
		"  <patch_keys>%s/patchkeys.txt</patch_keys>\n"
		" </ultima6>\n"
		"</config>\n",
		res.c_str(), res.c_str(), savedir.c_str(), res.c_str(), res.c_str());
	fclose(f);
}
#endif

#if defined(MACOSX) && !defined(NUVIE_IOS)
#include <XCodeBuild/main.cpp>
int nuvieMain(int argc, char **argv)
#else
int main(int argc, char **argv)
#endif
{
 Nuvie *nuvie;
 DEBUG(0,LEVEL_INFORMATIONAL,"Debugging enabled\n");
 DEBUG(1,LEVEL_DEBUGGING,"To disable debugging altogether, recompile with \"WITHOUT_DEBUG\" defined.\n");
 DEBUG(1,LEVEL_DEBUGGING,"To just get less spam, set the default for CurrentDebugLevel in Debug.cpp lower.\n");
 #ifdef NUVIE_IOS
 srandom(time(NULL));
 nuvie_ios_setup();
 #elif defined(MACOSX)
 srandom(time(NULL));


 CFBundleRef bundle = CFBundleGetMainBundle();
 if(bundle != NULL)
 {
	CFURLRef fileUrl = CFBundleCopyResourcesDirectoryURL(bundle);
	if (fileUrl) {
		// Try to convert the URL to an absolute path
		uint8 buf[MAXPATHLEN];
		if (CFURLGetFileSystemRepresentation(fileUrl, true, buf, sizeof(buf))) {
			// Success: Add it to the search path
         DEBUG(0,LEVEL_INFORMATIONAL, "Changing working dir to %s.\n", (const char *)buf);
			chdir((const char *)buf);
		}
		CFRelease(fileUrl);
	}
 }

 #else
 srand(time(NULL));
 #endif

 nuvie = new Nuvie;

 if(nuvie->init(argc, argv) == false)
 {
   ConsolePause();
   delete nuvie;
   return 1;
 }

 nuvie->play();

 delete nuvie;

 return 0;
}
