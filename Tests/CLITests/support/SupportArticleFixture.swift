struct SupportArticleFixture: Sendable {
    let path: String
    let title: String
    let introduction: String
    let html: String

    // Reduced from the support pages returned by the article and guide catalogs.
    static let standalone: [Self] = general + distribution

    private static let general: [Self] = [
        Self(
            path: "support/bimi",
            title: "Prepare your email server for BIMI support in Apple Mail",
            introduction: "Apple Mail in macOS Ventura 13, iOS 16, and iPadOS 16, or la",
            html: """
                <main id="main" class="main" role="main"><article><section class="section section-overview">
                <div class='section-content'><div class='row'><div class='column large-10'>
                <h1 class="typography-headline no-margin-top">Prepare your email server for BIMI support in
                Apple&nbsp;Mail</h1>
                <p>Apple Mail in macOS&nbsp;Ventura&nbsp;13, iOS&nbsp;16, and iPadOS&nbsp;16, or later supports BIMI
                (Brand Indicators for Message Identification), an email specification that enables email clients to
                show brand-controlled logos based on information provided by the corresponding organization.</p>
                </div></div></div></section></article></main>
                """),
        Self(
            path: "support/install-beta",
            title: "Installing and using Apple beta software",
            introduction: "Apple beta software, also referred to as a preview, seed, or",
            html: """
                <main id="main" class="main" role="main"><article _v="2.4"><section class="section
                section-install-beta">
                <div class='section-content'><div class='row'><div class='column large-10'>
                <h1 class="typography-hero-headline">Installing and using Apple beta software</h1>
                <p class="typography-intro">Apple beta software, also referred to as a preview, seed, or release
                candidate, is for developers to take advantage of the latest advancements in Apple platforms and
                test apps for compatibility.</p>
                </div></div></div></section></article></main>
                """),
        Self(
            path: "support/technical",
            title: "Code-level support",
            introduction: "Need help with technical or development issues for Apple fra",
            html: """
                <main id="main" class="main" role="main"><article _v="2.0"><section class="section
                section-technical">
                <div class='section-content'><div class='row'><div class='column large-10'>
                <h1>Code-level support</h1>
                <p class="typography-intro">Need help with technical or development issues for Apple frameworks,
                APIs, and tools?</p>
                </div></div></div></section></article></main>
                """),
        Self(
            path: "support/kernel-extensions",
            title: "Deprecated Kernel Extensions and System Extension Alternatives",
            introduction: "System extensions on",
            html: """
                <main id="main" class="main" role="main"><article><section class="section section-developer-id">
                <div class='section-content'><div class='row'><div class='column large-10'>
                <h1 class="typography-headline">Deprecated Kernel Extensions and System Extension Alternatives</h1>
                <p class="typography-intro">System extensions on <span class="nowrap">macOS Catalina 10.15</span> or
                later allow software, such as network extensions and endpoint security solutions, to extend the
                functionality of macOS without requiring kernel-level access.</p>
                </div></div></div></section></article></main>
                """),
        Self(
            path: "support/forums",
            title: "Apple Developer Forums",
            introduction: "Apple Developer Forums are a great place to post questions,",
            html: """
                <main id="main" class="main" role="main"><article _v="1.3"><section class="section section-forums">
                <div class='section-content'><div class='row'><div class='column large-10'>
                <h1 class="typography-headline no-margin-top">Apple&nbsp;Developer Forums</h1>
                <p class="typography-intro">Apple&nbsp;Developer&nbsp;Forums are a great place to post questions,
                exchange knowledge, and connect with fellow developers and Apple engineers on a variety of
                development topics.</p>
                </div></div></div></section></article></main>
                """),
        Self(
            path: "support/expiration",
            title: "Apple Worldwide Developer Relations Intermediate Certificate Expiration",
            introduction: "To help protect customers and developers, we require that al",
            html: """
                <main id="main" class="main" role="main"><article><section class="section section-certificates">
                <div class='section-content'><div class='row'><div class='column large-10'>
                <h1 class="typography-headline">Apple Worldwide Developer Relations Intermediate Certificate
                Expiration</h1>
                <p>To help protect customers and developers, we require that all third-party apps, Apple Wallet
                passes, Safari Extensions, Safari Push Notifications, and <span class="nowrap">App Store</span>
                purchase receipts are signed by a trusted certificate authority.</p>
                </div></div></div></section></article></main>
                """),
        Self(
            path: "support/ipv6",
            title: "IPv6-Only Networks",
            introduction: "As of June 1, 2016, all apps submitted to the",
            html: """
                <main id="main" class="main" role="main"><article><section class="section section-identity">
                <div class='section-content'><div class='row'><div class='column large-10'>
                <h1 class="typography-hero-headline">IPv6-Only Networks</h1>
                <p>As of June 1, 2016, all apps submitted to the <span class="nowrap">App Store</span> must support
                IPv6-only networks.</p>
                </div></div></div></section></article></main>
                """),
        Self(
            path: "support/sca",
            title: "Strong Customer Authentication Transactions",
            introduction: "Starting March 14, 2022, the Financial Conduct Authority (FC",
            html: """
                <body><article _v="1.1"><section class="section section-certificates">
                <div class='section-content'><div class='row'><div class='column large-10'>
                <h1 class="typography-headline">Strong Customer Authentication Transactions</h1>
                <p class="typography-intro">Starting March 14, 2022, the Financial Conduct Authority (FCA) will
                require Strong Customer Authentication (SCA) for users in the United Kingdom, which may impact how
                they complete online purchases.</p>
                </div></div></div></section></article></body>
                """),
        Self(
            path: "support/app-store",
            title: "App Store",
            introduction: "The App Store makes it simple for users to discover, purchas",
            html: """
                <main id="main" class="main" role="main"><article _v="1.2"><section class="section section-app-store
                bg-light">
                <div class='section-content'><div class='row'><div class='column large-10'>
                <h1 class="typography-headline">App&nbsp;Store</h1>
                <p class="typography-intro">The App&nbsp;Store makes it simple for users to discover, purchase, and
                download apps for iPhone, iPad, Mac, Apple&nbsp;TV, and Apple&nbsp;Watch.</p>
                </div></div></div></section></article></main>
                """),
        Self(
            path: "support/volume-purchase-and-custom-apps",
            title: "Distributing Apps on Apple Business and Apple School Manager",
            introduction: "All apps on the App Store are automatically available for vo",
            html: """
                <main id="main" class="main" role="main"><article _v="1.2"><section class="section section-volume">
                <div class='section-content'><div class='row'><div class='column large-10'>
                <h1 class="typography-headline">Distributing Apps on Apple Business and Apple School Manager</h1>
                <p class="typography-intro">All apps on the App&nbsp;Store are automatically available for volume
                purchase for the same price in Apple Business and Apple School Manager, which is where businesses
                and educational institutions download apps for volume distribution.</p>
                </div></div></div></section></article></main>
                """),
        Self(
            path: "support/protecting-users-from-suspicious-software",
            title: "Protecting Users from Suspicious Software",
            introduction: "Apple is committed to providing great experiences that respe",
            html: """
                <main id="main" class="main" role="main"><article><section class="section section-hero">
                <div class='section-content'><div class='row'><div class='column large-10'>
                <h1 class="typography-headline">Protecting Users from Suspicious Software</h1>
                <p class="typography-intro">Apple is committed to providing great experiences that respect customer
                privacy and security.</p>
                </div></div></div></section></article></main>
                """),
        Self(
            path: "support/required-device-capabilities",
            title: "Required Device Capabilities",
            introduction: "To ensure that people only download apps that their device s",
            html: """
                <main id="main" class="main bg-light" role="main"><article _v="1.2"><section class="section
                section-hero no-padding-bottom">
                <div class='section-content'><div class='row'><div class='column large-10'>
                <h1 class="typography-headline text-left">Required Device Capabilities</h1>
                <p class="typography-intro text-left">To ensure that people only download apps that their device
                supports, the App&nbsp;Store uses values in the <a
                href="/documentation/bundleresources/information_property_list/uirequireddevicecapabilities/"
                >UIRequiredDeviceCapabilities<span
                class="loc-en-only"></span></a> property list key to determine the hardware-related capabilities an
                app requires.</p>
                </div></div></div></section></article></main>
                """),
        Self(
            path: "support/unlisted-app-distribution",
            title: "Unlisted app distribution",
            introduction: "Release your apps that aren’t suited for public distribution",
            html: """
                <main id="main" class="main" role="main"><article _v="1.0"><section class="section
                section-overview">
                <div class='section-content'><div class='row'><div class='column large-10'>
                <h1 class="typography-headline">Unlisted app distribution</h1>
                <p>Release your apps that aren’t suited for public distribution as unlisted on the <span
                class="nowrap">App Store,</span> discoverable only with a direct link.</p>
                </div></div></div></section></article></main>
                """),
        Self(
            path: "support/dma-and-apps-in-the-eu",
            title: "Changes for apps in the European Union",
            introduction: "Since 2024, Apple has made updates to iOS, iPadOS, Safari, a",
            html: """
                <main id="main" role="main"><article _v="1.0"><section class="section section-hero bg-light">
                <div class='section-content'><div class='row'><div class='column large-10'>
                <h1 class="typography-headline large-centered">Changes for apps in the European&nbsp;Union</h1>
                <p class="typography-intro large-centered">Since 2024, Apple has made updates to iOS, iPadOS,
                Safari, and the App&nbsp;Store in the European&nbsp;Union (EU) to comply with the Digital Markets
                Act (DMA), giving developers more options in the EU — including the ability to process payments for
                digital goods and services outside of Apple&nbsp;In-App Purchase, distribute on alternative app
                marketplaces, operate alternative app marketplaces, distribute directly from their website, and use
                alternative browser engines.</p>
                </div></div></div></section></article></main>
                """),
    ]
}

extension SupportArticleFixture {
    private static let distribution: [Self] = [
        Self(
            path: "support/third-party-SDK-requirements",
            title: "Third-party SDK requirements",
            introduction: "Third-party software development kits (SDKs) can provide gre",
            html: """
                <main id="main" class="main" role="main"><article _v="1.0"><section class="section
                section-entitlements">
                <div class='section-content'><div class='row'><div class='column large-10'>
                <h1 class="typography-headline">Third-party SDK requirements</h1>
                <p>Third-party software development kits (SDKs) can provide great functionality for apps; they can
                also have the potential to impact user privacy in ways that aren’t obvious to developers and users.</p>
                </div></div></div></section></article></main>
                """),
        Self(
            path: "support/interoperability-requests",
            title: "Interoperability requests",
            introduction: "At Apple, enriching people’s lives with amazing experiences",
            html: """
                <main id="main" class="main" role="main"><article _v="1.0"><section class="section
                section-enrollment">
                <div class='section-content'><div class='row'><div class='column large-10'>
                <h1 class="typography-headline">Interoperability requests</h1>
                <p class="typography-intro">At Apple, enriching people’s lives with amazing experiences is a core
                value we share with developers.</p>
                </div></div></div></section></article></main>
                """),
        Self(
            path: "support/reader-apps",
            title: "Distributing “reader” apps with a link to your website",
            introduction: "Reader apps are apps that provide one or more of the followi",
            html: """
                <main id="main" class="main" role="main"><article _v="1.1"><section class="section
                section-enrollment">
                <div class='section-content'><div class='row'><div class='column large-10'>
                <h1 class="typography-headline">Distributing “reader” apps with a link to your website</h1>
                <p class="intro">Reader apps are apps that provide one or more of the following digital content
                types — magazines, newspapers, books, audio, music, or video — as the primary functionality of the
                app.</p>
                </div></div></div></section></article></main>
                """),
        Self(
            path: "support/age-assurance",
            title: "Age assurance frameworks Q&A",
            introduction: "Apple offers a number of frameworks and features that help d",
            html: """
                <main id="main" class="main" role="main"><article _v="1.0"><section class="section section-hero
                bg-light">
                <div class='section-content'><div class='row'><div class='column large-10'>
                <h1 class="typography-headline">Age assurance frameworks Q&amp;A</h1>
                <p class="typography-intro">Apple offers a number of frameworks and features that help developers
                comply with current and upcoming regional age assurance laws and related requirements.</p>
                </div></div></div></section></article></main>
                """),
        Self(
            path: "support/app-distribution-in-brazil",
            title: "Changes to iOS in Brazil",
            introduction: "As part of a recent agreement with Brazil’s competition regu",
            html: """
                <main id="main" role="main"><article _v="1.0"><section class="section section-hero bg-light">
                <div class='section-content'><div class='row'><div class='column large-10'>
                <h1 class="typography-headline large-centered">Changes to iOS in Brazil</h1>
                <p class="typography-intro large-centered">As part of a recent agreement with Brazil’s competition
                regulator CADE (Conselho Administrativo de Defesa Econômica), iOS 26.5 introduces new options for
                developers with apps in Brazil.</p>
                </div></div></div></section></article></main>
                """),
        Self(
            path: "support/app-distribution-in-japan",
            title: "Changes to iOS in Japan",
            introduction: "iOS 26.2 introduces changes for iOS to comply with the Mobil",
            html: """
                <main id="main" role="main"><article _v="1.0"><section class="section section-hero bg-light">
                <div class='section-content'><div class='row'><div class='column large-10'>
                <h1 class="typography-headline large-centered">Changes to iOS in Japan</h1>
                <p class="typography-intro large-centered">iOS&nbsp;26.2 introduces changes for iOS to comply with
                the Mobile Software Competition Act (MSCA), creating new options for developers with apps in Japan.</p>
                </div></div></div></section></article></main>
                """),
        Self(
            path: "support/apps-in-the-eu",
            title: "Changes for apps in the European Union",
            introduction: "Since 2024, Apple has made updates to iOS, iPadOS, Safari, a",
            html: """
                <main id="main" role="main"><article _v="1.0"><section class="section section-hero bg-light">
                <div class='section-content'><div class='row'><div class='column large-10'>
                <h1 class="typography-headline large-centered">Changes for apps in the European&nbsp;Union</h1>
                <p class="typography-intro large-centered">Since 2024, Apple has made updates to iOS, iPadOS,
                Safari, and the App&nbsp;Store in the European&nbsp;Union (EU) to comply with the Digital Markets
                Act (DMA), giving developers more options in the EU — including the ability to process payments for
                digital goods and services outside of Apple&nbsp;In-App Purchase, distribute on alternative app
                marketplaces, operate alternative app marketplaces, distribute directly from their website, and use
                alternative browser engines.</p>
                </div></div></div></section></article></main>
                """),
        Self(
            path: "support/storekit-external-entitlement-kr",
            title: "Distributing apps using a third-party payment provider in South Korea",
            introduction: "Following amendments to the Telecommunications Business Act",
            html: """
                <main id="main" class="main" role="main"><article _v="1.0"><section class="section
                section-enrollment">
                <div class='section-content'><div class='row'><div class='column large-10'>
                <h1 class="typography-headline">Distributing apps using a third-party payment provider in
                South&nbsp;Korea</h1>
                <p>Following amendments to the Telecommunications Business Act in South Korea, developers of apps
                distributed on the App&nbsp;Store solely in South&nbsp;Korea can use the StoreKit External Purchase
                Entitlement to use alternative payment service providers for in-app purchases.</p>
                </div></div></div></section></article></main>
                """),
        Self(
            path: "support/hce-transactions-in-apps",
            title: "HCE-based contactless NFC transactions for apps in the European Economic Area (EEA)",
            introduction: "iOS 17.4 or later includes APIs that support contactless tra",
            html: """
                <main id="main" class="main" role="main"><article _v="1.7"><section class="section section-renewal">
                <div class='section-content'><div class='row'><div class='column large-10'>
                <h1 class="typography-headline">HCE-based contactless NFC transactions for apps in the
                European&nbsp;Economic&nbsp;Area&nbsp;(EEA)</h1>
                <p class="typography-intro">iOS 17.4 or later includes APIs that support contactless transactions
                for in-store payments, car keys, closed loop transit, corporate badges, home keys, hotel keys,
                program membership, and event tickets from within compatible iOS apps using host card emulation
                (HCE).</p>
                </div></div></div></section></article></main>
                """),
        Self(
            path: "support/nfc-se-platform",
            title: "NFC & SE Platform for secure contactless transactions",
            introduction: "iOS 18.1 introduced APIs that support secure contactless tra",
            html: """
                <main id="main" class="main" role="main"><article _v="1.0"><section class="section
                section-platform">
                <div class='section-content'><div class='row'><div class='column large-10'>
                <h1 class="typography-headline">NFC&nbsp;&amp;&nbsp;SE Platform for secure contactless
                transactions</h1>
                <p class="typography-intro">iOS 18.1 introduced APIs that support secure contactless transactions
                within compatible iOS apps using the NFC&nbsp;&amp;&nbsp;SE Platform for in-store payments, car
                keys, closed loop transit, corporate badges, student ID, home keys, hotel keys, merchant loyalty and
                rewards, and event tickets.</p>
                </div></div></div></section></article></main>
                """),
    ]
}
