ETA iOS SDK
===========

Introduction
------------

This repository consists of a project, in which the SDK is used for demonstration purposes.  
To get started using the ETA SDK, simply copy ETA.h and ETA.m to your project. Both of these files can be found in the project folder.  
The ETA SDK can be used to easily call the REST API call documented on https://etilbudsavis.dk/developers/docs/.  
In addition the SDK provides a way for you to initialize a UIWebView and load a catalog within it.

Example Snippets
----------------

### Initialization
```objectivec
// Using the convenient factory method
ETA *eta = [ETA etaWithAPIKey:@"fewf32f34f34fq34f34f4345" apiSecret:@"3h45gkw34h5gl345uibn"];

// As both the API key and secret are public properties, we can alloc init as well.
// All calls to the ETA object before the API key and secret have been set, will be ignored.
ETA *etaOldSchool = [ETA alloc] init];
etaOldSchool.apiKey = @"fewf32f34f34fq34f34f4345";
etaOldSchool.apiSecret = @"3h45gkw34h5gl345uibn";
```