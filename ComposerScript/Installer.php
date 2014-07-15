<?php 

namespace ComposerScript;

use Composer\Script\Event;

class Installer {

	/**
	 * Hooks the post-package-install Composer event
	 *
	 * After a package is installed, we need to write
	 * process the package in case it's a MU plugin
	 * and we need to add the require files.
	 *
	 * @param Event $event A Composer Event object
	 * @return void
	 * @author Simon Wheatley
	 **/
	public static function post_package_install( Event $event ) {
		$composer  = $event->getComposer();
		$io        = $event->getIO();
		$operation = $event->getOperation();
		$package   = $operation->getPackage();
		$im        = $composer->getInstallationManager();

		$install_path = $im->getInstallPath( $package );

		self::handle_plugin_requires( $install_path, $io );
	}

	/**
	 * Hooks the pre-package-update Composer event
	 *
	 * Before a package is updated, we need to remove
	 * related require files, in case they are stale
	 * (we will recreate the required files after the
	 * package has been updated).
	 *
	 * @param Event $event A Composer Event object
	 * @return void
	 * @author Simon Wheatley
	 **/
	public static function pre_package_update( Event $event ) {
		$composer  = $event->getComposer();
		$io        = $event->getIO();
		$operation = $event->getOperation();
		$package   = $operation->getTargetPackage();
		$im        = $composer->getInstallationManager();

		$install_path = $im->getInstallPath( $package );

		self::remove_require_files( $install_path, $io );
	}

	/**
	 * Hooks the post-package-update Composer event
	 *
	 * After the package is updated, we write any
	 * require files we need.
	 * 
	 * @param Event $event A Composer Event object
	 * @return void
	 * @author Simon Wheatley
	 **/
	public static function post_package_update( Event $event ) {
		$composer  = $event->getComposer();
		$io        = $event->getIO();
		$operation = $event->getOperation();
		$package   = $operation->getTargetPackage();
		$im        = $composer->getInstallationManager();

		$install_path = $im->getInstallPath( $package );

		self::handle_plugin_requires( $install_path, $io );
	}

	/**
	 * Hooks the pre-package-uninstall Composer event
	 * 
	 * Before the package is uninstalled, while it still
	 * exists, we remove the require files.
	 *
	 * @param Event $event A Composer Event object
	 * @return void
	 * @author Simon Wheatley
	 **/
	public static function pre_package_uninstall( Event $event ) {
		$composer  = $event->getComposer();
		$io        = $event->getIO();
		$operation = $event->getOperation();
		$package   = $operation->getPackage();
		$im        = $composer->getInstallationManager();

		$install_path = $im->getInstallPath( $package );

		self::remove_require_files( $install_path, $io );
	}

	/**
	 * Process a mu-plugins installed package, creating the relevant
	 * require file(s).
	 *
	 * @param string $install_path The path to the package
	 * @param IOInterface $io The Composer IOInterface, for writing messages
	 * @return void
	 * @author Simon Wheatley
	 **/
	protected static function handle_plugin_requires( $install_path, $io ) {
		if ( 'htdocs/wp-content/mu-plugins' == dirname( $install_path ) ) {
			$plugin_files = self::get_plugin_files( $install_path );
			foreach ( $plugin_files as $plugin_file => $plugin_name ) {
				self::write_plugin_require( $io, $plugin_name, $plugin_file, $install_path );
			}
		}
	}

	/**
	 * Remove the require file for a mu-plugins installed package.
	 *
	 * @param string $install_path The path to the package
	 * @param IOInterface $io The Composer IOInterface, for writing messages
	 * @return void
	 * @author Simon Wheatley
	 **/
	protected static function remove_require_files( $install_path, $io ) {
		if ( 'htdocs/wp-content/mu-plugins' == dirname( $install_path ) ) {
			$plugin_files = self::get_plugin_files( $install_path );
			foreach ( $plugin_files as $plugin_file => $plugin_name ) {
				self::remove_plugin_require( $io, $plugin_name, $plugin_file, $install_path );
			}
		}
			
	}

	/**
	 * Get all the plugin files within the package, and their plugin names.
	 *
	 * @param strong $install_path The path to the Composer package (a mu-plugins subdirectory)
	 * @return array An array of plugin paths (key) and plugin names (value)
	 * @author Simon Wheatley
	 **/
	protected static function get_plugin_files( $install_path ) {
		$files = array();
		foreach ( glob( "{$install_path}*.php" ) as $file ) {
			$file_contents = file_get_contents( $file, false, null, -1, 8192 );
			if ( preg_match( '/^[ \t\/*#@]*Plugin Name:(.*)$/mi', $file_contents, $matches ) ) {
				$files[ $file ] = trim( $matches[1] );
			}
		}
		return $files;
	}

	/**
	 * Write a basic plugin file, which requires the relevant file
	 * inside mu-plugins/[folder].
	 *
	 * @param IOInterface $io The Composer IOInterface, for writing messages
	 * @param array $plugin_name A plugin name
	 * @param array $plugin_file A plugin file path
	 * @param string $install_path The path to the Composer package (a mu-plugins subdirectory)
	 * @return void
	 * @author Simon Wheatley
	 **/
	protected static function write_plugin_require( $io, $plugin_name, $plugin_file, $install_path ) {
		$lines = array();
		$lines[] = '<?php';
		$lines[] = '/**';
		$lines[] = sprintf( ' * Plugin Name: %s', $plugin_name );
		$lines[] = ' * ';
		$lines[] = ' * This file was autogenerated by a Composer install script ';
		$lines[] = sprintf( ' * located at: %s.', __FILE__ );
		$lines[] = ' */';
		$lines[] = '';
		$lines[] = sprintf( 'require_once( dirname( __FILE__ ) . \'/%s/%s\' );', basename( dirname( $plugin_file ) ), basename( $plugin_file ) );
		$lines[] = '';
		$file_contents = implode( PHP_EOL, $lines );
		$require_plugin_file = self::require_plugin_file_path( $install_path, $plugin_file );
		file_put_contents( $require_plugin_file, $file_contents );
		$io->write( sprintf( 'Created auto-require file for "%s" at %s', $plugin_name, $require_plugin_file ) );
	}

	/**
	 * Remove the basic plugin file, which requires the relevant file
	 * inside mu-plugins/[folder].
	 *
	 * @param IOInterface $io The Composer IOInterface, for writing messages
	 * @param array $plugin_name A plugin name
	 * @param array $plugin_file A plugin file path
	 * @param string $install_path The path to the Composer package (a mu-plugins subdirectory)
	 * @return void
	 * @author Simon Wheatley
	 **/
	protected static function remove_plugin_require( $io, $plugin_name, $plugin_file, $install_path ) {
		$require_plugin_file = self::require_plugin_file_path( $install_path, $plugin_file );
		unlink( $require_plugin_file );
		$io->write( sprintf( 'Removed auto-require file for "%s" at %s', $plugin_name, $require_plugin_file ) );
	}


	/**
	 * Provide the file path for a file within the mu-plugins folder.
	 *
	 * @param string $install_path The path to the Composer package (a mu-plugins subdirectory)
	 * @param string $plugin_file  The path to the plugin file within the Composer package
	 * @return string A file path
	 * @author Simon Wheatley
	 **/
	static function require_plugin_file_path( $install_path, $plugin_file ) {
		return sprintf( '%s/auto-require-%s', dirname( $install_path ), basename( $plugin_file ) );
	}
}
