SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: rdtGetConfig                                       */
/* Copyright: IDS                                                       */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 2006-10-17   dhung         Created                                   */
/* 2008-05-16   James         1) Change RETURNS from 10 CHAR to 20 CHAR */
/*                            2) Change @sValue declaration to 20 CHAR  */
/* 2013-04-30   James         SOS276235 - Allow storer group (james01)  */
/* 2017-10-17   Ung           WMS-3248 Add Facility                     */
/************************************************************************/
CREATE   FUNCTION rdt.rdtGetConfig(
   @nFunction_ID INT, 
   @cConfigKey   NVARCHAR( 30), 
   @cStorerKey   NVARCHAR( 15) = ''
) RETURNS NVARCHAR( 20) AS
BEGIN
   
   DECLARE @sValue NVARCHAR( 20)  
   DECLARE @cNewStorerKey NVARCHAR( 15)   -- (james01)
   
   DECLARE @cFacility NVARCHAR(5)
   DECLARE @cLoginFacility NVARCHAR(5)
           
   IF EXISTS (SELECT 1 FROM dbo.StorerGroup WITH (NOLOCK) 
              WHERE StorerGroup = @cStorerKey
              AND   StorerKey <> '')
   BEGIN
      -- If it is from storergroup then assume all storer under same storergroup 
      -- having same configuration 
      SELECT @sValue = SValue
      FROM rdt.StorerConfig SC WITH (NOLOCK)
      RIGHT JOIN StorerGroup SG WITH (NOLOCK) ON SC.StorerKey = SG.StorerKey
      WHERE Function_ID = @nFunction_ID
         AND ConfigKey = @cConfigKey
         AND SG.StorerGroup = @cStorerKey

      -- System level config
      IF @sValue IS NULL
         SELECT @sValue = NSQLValue
         FROM rdt.NSQLConfig (NOLOCK)
         WHERE Function_ID = @nFunction_ID
            AND ConfigKey = @cConfigKey

      GOTO Quit
   END
   
   -- Storer level config
   IF @cStorerKey <> '' AND @cStorerKey IS NOT NULL
   BEGIN
      SELECT 
         @sValue = SValue, 
         @cFacility = Facility
      FROM rdt.StorerConfig (NOLOCK)
      WHERE Function_ID = @nFunction_ID
         AND StorerKey = @cStorerKey
         AND ConfigKey = @cConfigKey
      
      -- Check facility config
      IF @@ROWCOUNT > 1 OR                               -- Multi record means facility config exist or
         (@cFacility <> '' AND @cFacility IS NOT NULL)   -- Single record with facility config
      BEGIN
         -- Get facility
         SELECT @cLoginFacility = Facility FROM rdt.rdtMobRec WITH (NOLOCK) WHERE UserName = SUSER_SNAME()
         
         -- Retrieve own facility config
         IF @cFacility <> @cLoginFacility
         BEGIN 
            SET @sValue = NULL

            -- Get config by facility, then by storer
            SELECT TOP 1 
               @sValue = SValue
            FROM rdt.StorerConfig (NOLOCK)
            WHERE Function_ID = @nFunction_ID
               AND StorerKey = @cStorerKey
               AND ConfigKey = @cConfigKey
               AND (Facility = '' OR Facility = @cLoginFacility)
            ORDER BY Facility DESC
         END
      END
   END
      
   -- System level config
   IF @sValue IS NULL
      SELECT @sValue = NSQLValue
      FROM rdt.NSQLConfig (NOLOCK)
      WHERE Function_ID = @nFunction_ID
         AND ConfigKey = @cConfigKey

   QUIT:
   RETURN IsNULL( @sValue, '0') -- Return default 0=Off if config is not defined
END

GO