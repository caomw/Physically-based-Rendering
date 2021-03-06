#include <QApplication>
#include <QDesktopWidget>

#include "source/Cfg.h"
#include "source/qt/Window.h"


int main( int argc, char** argv ) {
	setlocale( LC_ALL, "C" );
	Cfg::get().loadConfigFile( "config.json" );

	QApplication app( argc, argv );
	app.setWindowIcon( QPixmap( "icon.png" ) );

	Window window;
	window.resize( window.sizeHint() );

	float desktopArea = QApplication::desktop()->width() * QApplication::desktop()->height();
	float widgetArea = window.width() * window.height();

	if( widgetArea / desktopArea < 0.75f ) {
		window.show();
	}
	else {
		window.showMaximized();
	}

	return app.exec();
}
