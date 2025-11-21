SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1641DecodeSP01                                         */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Extended putaway                                                  */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 2023-05-05  Yeekung   1.0   WMS-22419 Created                              */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_1641DecodeSP01] (
   @nMobile       INT,          
   @nFunc         INT,          
   @cLangCode     NVARCHAR( 3), 
   @nStep         INT,          
   @nInputKey     INT,          
   @cStorerKey    NVARCHAR( 15),
   @cDropID       NVARCHAR( 20),
   @cBarcode      NVARCHAR( 2000),
   @cPrevLoadKey  NVARCHAR( 10),
   @cParam1       NVARCHAR(20), 
   @cParam2       NVARCHAR(20), 
   @cParam3       NVARCHAR(20), 
   @cParam4       NVARCHAR(20), 
   @cParam5       NVARCHAR(20), 
   @cUCCNo        NVARCHAR( 20) OUTPUT,
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @2DBarcode NVARCHAR(MAX)
   DECLARE @Boxreel NVARCHAR(30)

      IF @nInputKey = 1 -- ENTER
      BEGIN
         SELECT @2DBarcode = V_max
         FROM RDT.RDTMOBREC
         WHERE mobile = @nMobile
             
         DECLARE @tUCCtbl Table 
         ( 
         ROW INT NOT NULL identity(1,1),
         Value NVARCHAR(MAX)
         )
         DECLARE @cPatindex INT

         set @2DBarcode = replace(@2DBarcode,'<rs>','')

         set @2DBarcode = replace(@2DBarcode,'<eot>','')


         set @2DBarcode = replace(@2DBarcode,'<gs>',' ')


         set @2DBarcode = replace(@2DBarcode,'-','&')

         WHILE (1 = 1)
         BEGIN
            select  @cPatindex= patindex('%[^A-Z|0-9|/|&|'' '']%',@2DBarcode) 

            IF @cPatindex <>0
            BEGIN
               SET @2DBarcode = replace(@2DBarcode,substring(@2DBarcode,@cPatindex,1),' ')  
            END
            ELSE
               BREAK
         END


         set @2DBarcode = replace(@2DBarcode,'&','-')


         insert into @tUCCtbl (Value)
         select value from string_split(@2DBarcode,' ') where value<>''

         SELECT @Boxreel = Value
         FROM @tUCCtbl
         WHERE ROW = '8'

         SELECT @cUCCNo = Value + '-' + @Boxreel
         FROM @tUCCtbl
         WHERE ROW = '2'
      END
           

Quit:

END

GO