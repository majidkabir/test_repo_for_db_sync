SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: fnc_GetSKUfig                                      */
/* Copyright: IDS                                                       */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 25-03-2011   James         Created                                   */
/************************************************************************/
CREATE FUNCTION [dbo].[fnc_GetSKUConfig](
   @cSKU         NVARCHAR( 20), 
   @cConfigType  NVARCHAR( 30), 
   @cStorerKey   NVARCHAR( 15) = ''
) RETURNS NVARCHAR( 30) AS
BEGIN
   DECLARE @sData NVARCHAR( 30)

   -- Storer level config
   IF @cStorerKey <> '' AND @cStorerKey IS NOT NULL
      SELECT @sData = Data
      FROM dbo.SKUConfig (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND ConfigType = @cConfigType
         AND SKU = @cSKU
   
   RETURN IsNULL( @sData, '0') -- Return default 0=Off if config is not defined
END


GO