SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: rdtIsValidRange    					                  */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Validate range value                                        */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 2021-09-02   James         WMS-17833. Created                        */
/************************************************************************/

CREATE FUNCTION [RDT].[rdtIsValidRange] (
   @nFunc      INT, 
   @cStorerKey NVARCHAR( 15), 
   @cFieldName NVARCHAR( 10),
   @cType      NVARCHAR( 10),
   @cInput     NVARCHAR( 60)
) RETURNS INT AS
BEGIN
   DECLARE @iMatch   INT
   DECLARE @cPattern NVARCHAR(250)
   DECLARE @cCode    NVARCHAR(30)
   DECLARE @cFacility      NVARCHAR(5)  
   DECLARE @cLoginFacility NVARCHAR(5)  
   DECLARE @cFromRange     NVARCHAR( 60) = ''
   DECLARE @cToRange       NVARCHAR( 60) = ''
   
   SET @iMatch = 1
   SET @cCode = RTRIM( CAST( @nFunc AS NVARCHAR(5))) + '-' + @cFieldName

   -- Get RegEx pattern
   SET @cFacility = ''
   SET @cPattern = ''
   SELECT @cFacility = code2,
          @cFromRange = ISNULL( Short, ''),
          @cToRange = ISNULL( Long, '')
   FROM CodeLkup WITH (NOLOCK) 
   WHERE ListName = 'RDTRange' 
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
      SELECT 
          @cFromRange = ISNULL( Short, ''),
          @cToRange = ISNULL( Long, '')
      FROM CodeLkup WITH (NOLOCK) 
      WHERE ListName = 'RDTRange' 
         AND Code = @cCode 
         AND StorerKey = @cStorerKey
         AND (code2 = '' OR code2 = @cLoginFacility) 
      END
   END
 
   IF @cFromRange = '' OR @cToRange = ''
      GOTO Quit

   IF @cType = 'INT' AND CAST( @cInput AS INT) BETWEEN CAST( @cFromRange AS INT) AND CAST( @cToRange AS INT)
      SET @iMatch = 1
   ELSE IF @cType = 'FLOAT' AND CAST( @cInput AS FLOAT) BETWEEN CAST( @cFromRange AS FLOAT) AND CAST( @cToRange AS FLOAT)
      SET @iMatch = 1
   ELSE IF @cType = 'DATETIME' AND CAST( @cInput AS DATETIME) BETWEEN CAST( @cFromRange AS DATETIME) AND CAST( @cToRange AS DATETIME)
      SET @iMatch = 1
   ELSE
      SET @iMatch = 0
Quit:
   RETURN @iMatch
END

GO