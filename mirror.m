/*
 *  mirror.m
 *  mirror
 *
 *  Created by Fabian Canas on 2/4/09.
 *  Copyright 2009-2015 Fabián Cañas. All rights reserved.
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#import <Foundation/Foundation.h>
#import <ApplicationServices/ApplicationServices.h>

typedef NS_ENUM(NSUInteger, MirrorAction) {
    help,
    on,
    off,
    toggle,
    query
};

MirrorAction getAction()
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    
    NSArray *args = [[NSProcessInfo processInfo] arguments];
    NSArray *sorted_args = [args sortedArrayUsingSelector:@selector(compare:)];
    NSEnumerator *enm = [sorted_args objectEnumerator];
    
    NSString *arg;
    
    MirrorAction action = toggle;
    
    while (arg = [enm nextObject]) {
        if ([arg isEqualToString:@"-h"]){
            action = help;
            break;
        }
        if ([arg isEqualToString:@"-t"]){
            action = toggle;
            break;
        }
        if ([arg isEqualToString:@"-on"]){
            action = on;
            break;
        }
        if ([arg isEqualToString:@"-off"]){
            action = off;
            break;
        }
        if ([arg isEqualToString:@"-q"]){
            action = query;
            break;
        }
    }
    
    [pool drain];
    return action;
}

#define MAX_DISPLAYS 10
#define SECONDARY_DISPLAY_COUNT 9

static CGDisplayCount numberOfTotalDspys = MAX_DISPLAYS;

static CGDirectDisplayID activeDspys[MAX_DISPLAYS];
static CGDirectDisplayID onlineDspys[MAX_DISPLAYS];
static CGDirectDisplayID secondaryDspys[SECONDARY_DISPLAY_COUNT];

void multiConfigureDisplays(CGDisplayConfigRef configRef, CGDirectDisplayID *secondaryDspys, int count, CGDirectDisplayID master) {
    for (int i = 0; i<count; i++) {
        CGConfigureDisplayMirrorOfDisplay(configRef, secondaryDspys[i], master);
    }
}

int main (int argc, const char * argv[]) {
    
    MirrorAction action = getAction();
    
    if (action == help){
        printf("Mirror Displays version 1.1\nCopyright 2009-2015, Fabián Cañas\n");
        printf("usage: mirror [option]\tPassing more than one option produces undefined behavior.");
        printf("\n  -h\t\tPrint this usage and exit.");
        printf("\n  -t\t\tToggle mirroring (default behavior)");
        printf("\n  -on\t\tTurn Mirroring On");
        printf("\n  -off\t\tTurn Mirroring Off");
        printf("\n  -q\t\tQuery the Mirroring state and write \"on\" or \"off\" to stdout");
        printf("\n");
        return 0;
    }
    
    CGDisplayCount numberOfActiveDspys;
    CGDisplayCount numberOfOnlineDspys;
    
    CGDisplayErr activeError = CGGetActiveDisplayList (numberOfTotalDspys,activeDspys,&numberOfActiveDspys);
    
    if (activeError!=0) NSLog(@"Error in obtaining active diplay list: %d\n",activeError);
    
    CGDisplayErr onlineError = CGGetOnlineDisplayList (numberOfTotalDspys,onlineDspys,&numberOfOnlineDspys);
    
    if (onlineError!=0) NSLog(@"Error in obtaining online diplay list: %d\n",onlineError);
    
    if (numberOfOnlineDspys<2) {
        printf("No secondary display detected.\n");
        return 1;
    }
    
    bool displaysMirrored = CGDisplayIsInMirrorSet(CGMainDisplayID());
    int secondaryDisplayIndex = 0;
    for (int displayIndex = 0; displayIndex<numberOfOnlineDspys; displayIndex++) {
        if (onlineDspys[displayIndex] != CGMainDisplayID()) {
            secondaryDspys[secondaryDisplayIndex] = onlineDspys[displayIndex];
            secondaryDisplayIndex++;
        }
    }
    
    CGDisplayConfigRef configRef;
    CGError err = CGBeginDisplayConfiguration (&configRef);
    if (err != 0) NSLog(@"Error with CGBeginDisplayConfiguration: %d\n",err);
    // Experimental Code for changing the color and timing for the fade effect.
    //CGError fadeChangeError;
    //fadeChangeError = CGConfigureDisplayFadeEffect (configRef,1.5,1.5,0.0,0.0,0.0);
    //if (fadeChangeError!= 0) NSLog(@"Error with CGConfigureDisplayFadeEffect %d\n",fadeChangeError);
    
    if (action == toggle) {
        if (displaysMirrored) {
            action = off;
        } else {
            action = on;
        }
    }
    
    switch (action) {
        case on:
            multiConfigureDisplays(configRef, secondaryDspys, numberOfOnlineDspys - 1, CGMainDisplayID());
            break;
        case off:
            multiConfigureDisplays(configRef, secondaryDspys, numberOfOnlineDspys - 1, kCGNullDirectDisplay);
            break;
        case query:
            if (displaysMirrored) { // Displays are unmirrored
                printf("on\n");
            } else { // Displays are mirrored
                printf("off\n");
            }
            break;
        default:
            break;
    }
    if (err != 0) NSLog(@"Error configuring displays: %d\n",err);
    
    // Apply the changes
    err = CGCompleteDisplayConfiguration (configRef,kCGConfigurePermanently);
    if (err != 0) NSLog(@"Error with applying configuration: %d\n",err);
    
    return err;
}
