SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_838DataCap03                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 14-12-2021 1.0  Chermaine   WMS-18503 Created                        */
/* 14-02-2022 1.1  YeeKung     WMS-18323 Add params (yeekung01)         */
/************************************************************************/

CREATE   PROC [RDT].[rdt_838DataCap03] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cFacility        NVARCHAR( 5),
   @cStorerKey       NVARCHAR( 15),
   @cPickSlipNo      NVARCHAR( 10),
   @cFromDropID      NVARCHAR( 20),
   @nCartonNo        INT,
   @cLabelNo         NVARCHAR( 20),
   @cSKU             NVARCHAR( 20),
   @nQTY             INT,
   @cUCCNo           NVARCHAR( 20),
   @cCartonType      NVARCHAR( 10),
   @cCube            NVARCHAR( 10),
   @cWeight          NVARCHAR( 10),
   @cRefNo           NVARCHAR( 20),
   @cSerialNo        NVARCHAR( 30),
   @nSerialQTY       INT,
   @cOption          NVARCHAR( 1),
   @cPackDtlRefNo    NVARCHAR( 20), 
   @cPackDtlRefNo2   NVARCHAR( 20), 
   @cPackDtlUPC      NVARCHAR( 30), 
   @cPackDtlDropID   NVARCHAR( 20), 
   @cPackData1       NVARCHAR( 30)  OUTPUT, 
   @cPackData2       NVARCHAR( 30)  OUTPUT, 
   @cPackData3       NVARCHAR( 30)  OUTPUT,
	@cPackLabel1      NVARCHAR( 20)  OUTPUT, --(yeekung01)
   @cPackLabel2      NVARCHAR( 20)  OUTPUT, --(yeekung01)
   @cPackLabel3      NVARCHAR( 20)  OUTPUT, --(yeekung01)
	@cPackAttr1       NVARCHAR( 1)   OUTPUT, --(yeekung01)
   @cPackAttr2       NVARCHAR( 1)   OUTPUT, --(yeekung01)
   @cPackAttr3       NVARCHAR( 1)   OUTPUT, --(yeekung01)
   @cDataCapture     NVARCHAR( 1)   OUTPUT, 
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nRowCount   INT
   DECLARE @cOrderKey   NVARCHAR( 10) = ''
   DECLARE @cLoadKey    NVARCHAR( 10) = ''
   DECLARE @cZone       NVARCHAR( 18) = ''
   DECLARE @cPrevPackData1 NVARCHAR( 30) = ''
   DECLARE @cPickStatus NVARCHAR(1)
   
   SET @cPrevPackData1 = @cPackData1  
   SET @cPackData1 = ''  
   SET @cPackData2 = ''  
   SET @cPackData3 = ''  

   IF EXISTS (SELECT 1
               FROM SKU S WITH (NOLOCK)
               JOIN codelkup C WITH (NOLOCK) ON (c.Storerkey = s.StorerKey AND c.code = s.BUSR1)
               WHERE S.storerKey = @cStorerKey
               AND S.SKU = @cSKU
               AND c.LISTNAME = 'TMBUSR1' )
   BEGIN
      SET @cDataCapture = '1'---- need to capture
      SET @cPackData1 = ''
      
      SET @cPackAttr1=''
      SET @cPackAttr2=''
      SET @cPackAttr3=''
	   SET @cPackLabel1='Data 1:'--(yeekung01)
	   SET @cPackLabel2='Data 2:'--(yeekung01)
	   SET @cPackLabel3='Data 3:'--(yeekung01)
      EXEC rdt.rdtSetFocusField @nMobile, 1 -- PackData1  
   END   
   ELSE
   BEGIN
      SET @cDataCapture = '0'
   END
END

GO