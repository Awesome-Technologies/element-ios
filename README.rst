Build Status
============
|Build Status|

.. |Build Status| image:: https://app.bitrise.io/app/40c6dbdbcc7e7729/status.svg?token=w0kqHzGK81RuPm_Pjc2Ajg&branch=Caritas
:target: https://app.bitrise.io/app/40c6dbdbcc7e7729

Build status is shown for Caritas branch.

Caritas Messenger
=================

The Caritas messenger is an iOS Matrix client for internal communication between the staff.

It is based on the Riot-iOS (https://github.com/vector-im/riot-ios) app and therefore also MatrixKit (https://github.com/matrix-org/matrix-ios-kit) and MatrixSDK (https://github.com/matrix-org/matrix-ios-sdk).

You can build the app from source as per below:

Build instructions
==================

Before opening the Riot Xcode workspace, you need to build it with the
CocoaPods command::

        $ cd Riot
        $ pod install

This will load all dependencies for the Riot source code, including MatrixKit
and MatrixSDK.  You will need a recent and updated (``pod update``) install of
CocoaPods.

Then, open ``Riot.xcworkspace`` with Xcode

        $ open Riot.xcworkspace

Developing
==========

Main development happens on the Caritas branch. You can edit the podfile to adjust the used MatrixKit version. Once you are done editing the ``Podfile``, run ``pod install``.

You may need to change the bundle identifier and app group identifier to be unique to get Xcode to build the app. Make sure to change the application group identifier everywhere by running a search for ``group.care.amp.messenger.caritas`` and changing every spot that identifier is used to your new identifier.

Copyright & License
===================

Copyright (c) 2014-2017 OpenMarket Ltd
Copyright (c) 2017 Vector Creations Ltd
Copyright (c) 2017-2019 New Vector Ltd
Copyright (c) 2018 Awesome Technologies Innovationslabor GmbH

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this work except in compliance with the License. You may obtain a copy of the License in the LICENSE file, or at:

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
