/*
 * This file was generated by the Gradle 'init' task.
 *
 * This generated file contains a sample Gradle plugin project to get you started.
 * For more details on writing Custom Plugins, please refer to https://docs.gradle.org/8.12.1/userguide/custom_plugins.html in the Gradle documentation.
 * This project uses @Incubating APIs which are subject to change.
 */

plugins {
    // Apply the Java Gradle plugin development plugin to add support for developing Gradle plugins
    `java-gradle-plugin`

    // Apply the Kotlin JVM plugin to add support for Kotlin.
    alias(libs.plugins.kotlin.jvm)
}

repositories {
    // Use Maven Central for resolving dependencies.
    mavenCentral()
}

testing {
    suites {
        // Configure the built-in test suite
        val test by getting(JvmTestSuite::class) {
            // Use Kotlin Test test framework
            useKotlinTest("2.0.21")
        }

        // Create a new test suite
        val functionalTest by registering(JvmTestSuite::class) {
            // Use Kotlin Test test framework
            useKotlinTest("2.0.21")

            dependencies {
                // functionalTest test suite depends on the production code in tests
                implementation(project())
            }

            targets {
                all {
                    // This test suite should run after the built-in test suite has run its tests
                    testTask.configure { shouldRunAfter(test) } 
                }
            }
        }
    }
}

gradlePlugin {
    // Define the plugin
    val greeting by plugins.creating {
        id = "org.example.greeting"
        implementationClass = "org.example.BsfiotPlugin"
    }
}

gradlePlugin.testSourceSets.add(sourceSets["functionalTest"])

tasks.named<Task>("check") {
    // Include functionalTest as part of the check lifecycle
    dependsOn(testing.suites.named("functionalTest"))
}
