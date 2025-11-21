SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_1641ExtInfo01                                         */
/* Purpose: Display scanned carton id                                         */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2016-06-07 1.0  James    SOS370791 Created                                 */
/* 2016-10-12 1.1  James    Include step 1 in display extended info (james01) */        
/******************************************************************************/

CREATE PROC [RDT].[rdt_1641ExtInfo01] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR(3),
   @nStep            INT,
   @nInputKey        INT, 
   @cStorerKey       NVARCHAR(15),
   @cDropID          NVARCHAR(20),
   @cUCCNo           NVARCHAR(20),
   @cParam1          NVARCHAR(20),
   @cParam2          NVARCHAR(20),
   @cParam3          NVARCHAR(20),
   @cParam4          NVARCHAR(20),
   @cParam5          NVARCHAR(20),
   @cExtendedInfo1   NVARCHAR( 20) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

IF @nFunc = 1641
BEGIN
   DECLARE @cPickSlipNo       NVARCHAR( 10),
           @cOrderKey         NVARCHAR( 10), 
           @cColumnName       NVARCHAR( 20), 
           @cTableName        NVARCHAR( 20), 
           @cExecStatements   NVARCHAR( 4000), 
           @cExecArguments    NVARCHAR( 4000),
           @cCode             NVARCHAR( 10),
           @cDataType         NVARCHAR( 128),
           @cValue            NVARCHAR( 60),
           @cPrefixLen        NVARCHAR( 60),
           @cUDF01            NVARCHAR( 60),
           @cUDF02            NVARCHAR( 60),
           @cUDF03            NVARCHAR( 60),
           @cUDF04            NVARCHAR( 60),
           @cUDF05            NVARCHAR( 60),
           @cParamLabel1      NVARCHAR( 20),
           @cParamLabel2      NVARCHAR( 20),
           @cParamLabel3      NVARCHAR( 20),
           @cParamLabel4      NVARCHAR( 20),
           @cParamLabel5      NVARCHAR( 20),
           @cPalletCriteria   NVARCHAR( 20),
           @cNotes            NVARCHAR( 60),
           @cRoute            NVARCHAR( 30),
           @cCurRoute         NVARCHAR( 30),
           @cCaseID           NVARCHAR( 20),
           @nCount            INT, 
           @nDebug            INT, 
           @nStart            INT,
           @nLen              INT

   SET @nDebug = 0
   
   DECLARE @cErrMsg1          NVARCHAR( 20),
           @cErrMsg2          NVARCHAR( 20),
           @cErrMsg3          NVARCHAR( 20),
           @cErrMsg4          NVARCHAR( 20),
           @cErrMsg5          NVARCHAR( 20)

   IF @nStep IN (1, 3) -- UCC
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         SET @nCount = 0
         SELECT @nCount = Count ( DISTINCT CaseID)
         FROM dbo.PALLETDETAIL WITH (NOLOCK)
         WHERE PalletKey = @cDropID
         AND   StorerKey = @cStorerKey
         AND   [Status] < '9'

         SET @cExtendedInfo1 = 'SCANNED:' + CAST( @nCount AS NVARCHAR( 3))
      END   -- ENTER
   END   
END

Quit:



GO