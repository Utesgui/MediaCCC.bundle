using MediaBrowser.Model.Plugins;

namespace Jellyfin.Plugin.MediaCCC.Configuration
{
    /// <summary>
    /// Klasse für die Konfiguration des MediaCCC-Plugins.
    /// </summary>
    public class PluginConfiguration : BasePluginConfiguration
    {
        /// <summary>
        /// Initializes a new instance of the <see cref="PluginConfiguration"/> class.
        /// </summary>
        public PluginConfiguration()
        {
            // Standardwerte setzen
            MaxItems = 100;
            EnabledForMovies = true;
            CacheMinutes = 60;
        }

        /// <summary>
        /// Maximale Anzahl an Items, die geladen werden sollen.
        /// </summary>
        public int MaxItems { get; set; }

        /// <summary>
        /// Gibt an, ob das Plugin für Filme aktiviert ist.
        /// </summary>
        public bool EnabledForMovies { get; set; }

        /// <summary>
        /// Cache-Zeit in Minuten.
        /// </summary>
        public int CacheMinutes { get; set; }
    }
}
