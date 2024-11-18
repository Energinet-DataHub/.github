# Read description in the 'views.dsl' file.

workspace "DataHub" {

    # Enable hierarchical element identifier (relationship identifiers are unaffected).
    # See https://github.com/structurizr/dsl/blob/master/docs/language-reference.md#identifier-scope
    !identifiers hierarchical

    model {
        properties {
            # Enable nested groups.
            # See https://github.com/structurizr/dsl/tree/master/docs/cookbook/groups#nested-groups
            "structurizr.groupSeparator" "/"
        }

        group "Electricity Supplier or Grid Company" {
            dh3User = person "DH3 User - 6" {
                description "Person who interacts with DataHub."
                tags ""
            }

            actorB2BSystem = softwareSystem "Actor B2B System" {
                description "External business transaction system. System-to-system communication (B2B)."
                tags "Actor"
            }
        }
        group "Business or private person" {
            elOverblikUser = person "ElOverblik user" {
                description "Person who interacts with ElOverblik. Both private and business users."
                tags ""
            }
            elOverblikThirdPartyUser = softwareSystem "Eloverblik Third Party" {
                description "System that interacts with ElOverblik on behalf of a user."
                tags "Actor"
            }
            ettDkThirdPartySystem = softwareSystem "Energy Track and Trace DK Third Party" {
                description "Third party system that interacts with Energy Origin APIs."
                tags "Actor"
            }
            ettDkUser = person "Energy Track and Trace DK user" {
                description "Person who on behalf of a power producer/consumer interacts with Energy Track and Trace DK."
            }
        }

        group "CGI Organization" {
            dh2 = softwareSystem "DataHub 2.0" {
                description "Existing DataHub system. Provides uniform communication and standardized processes for actors operating on the Danish electricity market."
                tags "Out of focus"
            }
        }

        group "eSett Organization" {
            eSett = softwareSystem "eSett" {
                description "Balance settlement system for the Nordic electricity market."
                tags "Out of focus"
            }
        }
        group "Signaturgruppen Organization" {
            mitId = softwareSystem "MitID" {
                description "MitID is a common login solution for the public sector in Denmark."
                tags "Out of focus"
            }
        }
        group "Erhvervsstyrelsen" {
            cvr = softwareSystem "CVR" {
                description "CVR is a state owned company register in Denmark."
                tags "Out of focus"
            }
        }
        group "GitHub Organization" {
            github = softwareSystem "GitHub" {
                description "GitHub is a code hosting platform for version control, collaboration and running deployment pipelines."
                tags "Out of focus"
            }
        }
        group "Microsoft" {
            azureAdB2c = softwareSystem "Azure AD B2C" {
                description "Identity provider."
                tags "Out of focus"
            }
        }


        group "Energinet Organization" {
            btESett = softwareSystem "BizTalk eSett" {
                description "Handles communication and network between Energinet and eSett."
                tags "Out of focus"
            }
            eds = softwareSystem "Energi Data Service" {
                description "Data and services about the Danish energy system such as CO2 emissions and consumption and production data."
                tags "Out of focus"
            }
            poRegistry = softwareSystem "Project Origin Registry" {
                description "Public permissioned distributed ledger where everyone can validate the granular certificates for their electricity."
                tags "Out of focus"
            }
            poWallet = softwareSystem "Project Origin Vault" {
                description "System with wallets to hold granular certificates in the registries."
                tags "Out of focus"
            }
            poStamp = softwareSystem "Project Origin Stamp" {
                description "Certificate issuance system."
                tags "Out of focus"
            }
            azureAD = softwareSystem "Azure AD" {
                description "Manages identities and RBAC across the organization."
                tags "Out of focus"
            }

            group "DataHub Organization" {
                dhDeveloper = person "DataHub Developer" {
                    description "Person who works within Energinet DataHub."
                }
                dhSystemAdmin = person "DataHub System Admin" {
                    description "Person who works within Energinet DataHub."
                    tags ""
                }
                elOverblik = softwareSystem "Eloverblik" {
                    description "The platform provides data on electricity consumption and production, allowing customers to have a comprehensive overview across grid areas and energy suppliers."
                    # Extend with groups and containers in separate repos
                }
                ettDk = softwareSystem "Energy Track and Trace DK" {
                    description "Provides a way to issue and claim granular certificates."
                    # Extend with groups and containers in separate repos
                }
                dhESett = softwareSystem "DataHub eSett" {
                    description "Converts ebix messages, which contain aggregated energy time series, into a format eSett understands (nbs)."
                    tags ""
                }
                dh3 = softwareSystem "DataHub 3.0" {
                    description "Provides uniform communication and standardized processes for actors operating on the Danish electricity market."
                    tags ""

                    # Shared containers must be added in the base model

                    sharedUnityCatalog = container "Unity Catalog" {
                        description "Subsystem data and data products"
                        technology "Azure Databricks"
                        tags "Intermediate Technology" "Microsoft Azure - Azure Databricks"
                    }
                    sharedKeyVault = container "Key Vault" {
                        description "Store for secrets and signing keys"
                        technology "Azure Key Vault"
                        tags "Microsoft Azure - Key Vaults"
                    }
                    sharedApiManagement = container "API Management" {
                        description "Expose URL endpoints to the public"
                        technology "Azure - API Management"
                        tags "Microsoft Azure - API Management Services"
                    }
                    sharedServiceBus = container "Message broker" {
                        description "Message broker with message queues and publish-subscribe topics"
                        technology "Azure Service Bus"
                        tags "Intermediate Technology" "PaaS" "Microsoft Azure - Azure Service Bus"
                    }
                    sharedInternalSendGrid = container "SendGrid (internal)" {
                        description "EMail dispatcher for internal use"
                        technology "Twilio SendGrid"
                        tags "Intermediate Technology" "SaaS" "Microsoft Azure - SendGrid Accounts"
                    }
                    sharedExternalSendGrid = container "SendGrid (external)" {
                        description "EMail dispatcher for external use"
                        technology "Twilio SendGrid"
                        tags "Intermediate Technology" "SaaS" "Microsoft Azure - SendGrid Accounts"

                        # Base model relationships
                        this -> dh3User "Sends mail"
                    }
                    sharedB2C = container "App Registrations (shared)" {
                        description "Cloud identity directory."
                        technology "Azure AD B2C"
                        tags "Microsoft Azure - Azure AD B2C"

                        # Base model relationships
                        actorB2BSystem -> this "Request OAuth token" "https" {
                            tags "OAuth"
                        }

                        elOverblik -> this "Request OAuth token" "https" {
                            tags "OAuth"
                        }
                    }

                    # Extend with groups and containers in separate repos
                }
                acorn = softwareSystem "Acorn" {
                    description "PaaS running on Kubernetes orchestrated by infrastructure as code principles for hosting product applications."
                    tags ""
                }
                dh3Platform = softwareSystem "DH3 Platform" {
                    description "Azure-based platform, yet to be given a name"
                    tags ""
                }
            }
        }


        # Relationships to/from
        # DH eSett
        dhESett -> btESett "Sends calculations" "https"
        btESett -> eSett "Sends calculations" "<add technology>"
        dhSystemAdmin -> dhESett "Monitors" "browser"
        # DH2
        dhESett -> dh2 "Requests <data>" "peek+dequeue/https"
        # DH3
        elOverblik -> dh2 "Requests <data>" "https"
        dhSystemAdmin -> dh3 "Uses" "browser"
        dh3User -> dh3 "Uses" "browser"
        actorB2BSystem -> dh3 "Requests calculations" "peek+dequeue/https"
        dh2 -> dh3 "Transfers <data>" "AzCopy/https"
        github -> dh3 "Pushes artifacts and data" "https"
        # ElOverblik
        elOverblikUser -> elOverblik "Requests <data>" "browser"
        elOverblikThirdPartyUser -> elOverblik "Requests <data>" "https"
        elOverblik -> eds "Requests emission and residual mix data" "https"
        elOverblik -> mitId "Authenticate users" "https"
        elOverblik -> cvr "Reads CVR data" "https"
        github -> elOverblik "Pushes artifacts and data" "https"
        elOverblik -> dh3 "Data" "https"
        # Energy Track and Trace DK
        ettDk -> dh2 "Requests measurements" "https"
        ettDk -> poRegistry "Links to guarantees of origin" "https"
        ettDk -> poWallet "Places certificates in" "https"
        ettDk -> poStamp "Issues certificates" "https"
        ettDk -> mitId "Authenticate users" "https"
        ettDk -> azureAdB2c "Authenticates using" "OIDC"
        ettDkUser -> ettDk "Reads/manages granular certificates" "browser"
        ettDkThirdPartySystem -> ettDk "Integrates with platform on behalf of users" "https"
        ettDk -> cvr "Reads CVR data" "https"
        # Platforms
        dhDeveloper -> acorn "manages"
        acorn -> ettDk "Supports/hosts" ""
        acorn -> elOverblik "Supports/hosts" ""
        acorn -> poRegistry "hosts" ""
        acorn -> poWallet "hosts" ""
        dh3Platform -> dh3 "Supports/hosts" ""
    }

    views {
        # Place any 'views' in the 'views.dsl' file.

        themes default https://static.structurizr.com/themes/microsoft-azure-2023.01.24/icons.json
        styles {
            # Use to mark an element that is somehow not compliant to the projects standards.
            element "Not Compliant" {
                background #ffbb55
                color #ffffff
            }
            # Use to mark an element that is acting as a mediator between other elements in focus.
            # E.g. an element that we would like to show for the overall picture, to be able to clearly communicate dependencies.
            # Typically this is an element that we configure, instead of develop.
            element "Intermediate Technology" {
                background #dddddd
                color #999999
            }
            # Use to mark an elements that is not an active part of the DataHub 3.0 project.
            # E.g. an software system to which the project has dependencies.
            element "Out of focus" {
                background #999999
                color #ffffff
            }
            element "Infrastructure Node" {
                background #dddddd
            }
            element "Data Storage" {
                shape Cylinder
            }
            # Style for the DataHub Organization group which should make it stand out compared to other groups.
            element "Group:Energinet Organization/DataHub Organization" {
                color #0000ff
            }
            element "Person" {
                shape person
                background #08427b
                color #ffffff
            }
            element "Web Browser" {
                shape WebBrowser
            }
            element "Actor" {
                shape RoundedBox
                background #08427b
                color #ffffff
            }
        }
    }
}
