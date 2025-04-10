using System.Collections.Generic;
using System.Text.Json.Serialization;

namespace Jellyfin.Plugin.MediaCCC.Api.Models
{
    /// <summary>
    /// Repräsentiert detaillierte Informationen zu einer Konferenz.
    /// </summary>
    public class ConferenceDetail : Conference
    {
        /// <summary>
        /// Gets or sets the events.
        /// </summary>
        [JsonPropertyName("events")]
        public List<Event> Events { get; set; }
    }
}
