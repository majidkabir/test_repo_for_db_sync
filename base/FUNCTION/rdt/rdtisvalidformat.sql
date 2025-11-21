SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtIsValidFormat                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author     Purposes                                */
/* 06-Mar-2014  1.0  Ung        Created                                 */
/* 03-Jul-2015  1.1  Ung        SOS315262 Add check blank, null         */
/* 30-Apr-2020  1.2  James      WMS-13073 Add facility checking(james01)*/
/* 26-Jul-2022  1.3  Ung        WMS-18861 Expand @cFieldName            */
/************************************************************************/

CREATE   FUNCTION [RDT].[rdtIsValidFormat](
   @nFunc      INT, 
   @cStorerKey NVARCHAR( 15), 
   @cFieldName NVARCHAR( 25), 
   @cInput     NVARCHAR( 60)
) RETURNS INT AS -- 0=false, 1=true
BEGIN
   DECLARE @iMatch   INT
   DECLARE @cPattern NVARCHAR(250)
   DECLARE @cCode    NVARCHAR(30)
   DECLARE @cFacility      NVARCHAR(5)  
   DECLARE @cLoginFacility NVARCHAR(5)  
   
   SET @iMatch = 1 -- True
   SET @cCode = RTRIM( CAST( @nFunc AS NVARCHAR(5))) + '-' + @cFieldName

   -- Get RegEx pattern
   SET @cFacility = ''
   SET @cPattern = ''
   SELECT @cFacility = code2,
          @cPattern = ISNULL( Long, '')
   FROM CodeLkup WITH (NOLOCK) 
   WHERE ListName = 'RDTFormat' 
      AND Code = @cCode 
      AND StorerKey = @cStorerKey

   -- Check facility config  
   IF @@ROWCOUNT > 1 OR                               -- Multi record means facility config exist or  
      (@cFacility <> '' AND @cFacility IS NOT NULL)   -- Single record with facility config  
   BEGIN  
      -- Get facility  
      SELECT @cLoginFacility = Facility 
      FROM rdt.rdtMobRec WITH (NOLOCK) 
      WHERE UserName = SUSER_SNAME()  

      -- Retrieve own facility config  
      IF @cFacility <> @cLoginFacility  
      BEGIN   
         -- Get config by facility, then by storer  
         SET @cPattern = ''
         SELECT @cPattern = ISNULL( Long, '')
         FROM CodeLkup WITH (NOLOCK) 
         WHERE ListName = 'RDTFormat' 
            AND Code = @cCode 
            AND StorerKey = @cStorerKey
            AND (code2 = '' OR code2 = @cLoginFacility) 
      END
   END
   
   IF @cPattern = '' 
      GOTO Quit

   SELECT @iMatch = master.dbo.RegExIsMatch( @cPattern, @cInput, 0) -- 0=RegexOptions.None

Quit:
   RETURN @iMatch
END

GO