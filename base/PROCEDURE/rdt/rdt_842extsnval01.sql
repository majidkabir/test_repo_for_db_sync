SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_842ExtSNVal01                                         */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Check validity of gift card. Return error if it not               */
/*                                                                            */
/*                                                                            */
/* Date        Rev  Author       Purposes                                     */
/* 2021-01-29  1.0  James        WMS-15880. Created                           */
/* 2021-03-08  1.1  James        Add config for DTSITF db name (james01)      */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_842ExtSNVal01]
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cFacility        NVARCHAR( 3),
   @cStorerKey       NVARCHAR( 15),
   @cSKU             NVARCHAR( 20),
   @nQTY             INT, 
   @cSerialNo        NVARCHAR( 30),
   @cType            NVARCHAR( 15), --CHECK/INSERT
   @cDocType         NVARCHAR( 10), 
   @cDocNo           NVARCHAR( 20), 
   @nErrNo           INT           OUTPUT,
   @cErrMsg          NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess    INT
   DECLARE @nErr        INT
   DECLARE @cOutErrMsg  NVARCHAR(250)
   DECLARE @cOrderkey   NVARCHAR( 10)
   DECLARE @cDropID     NVARCHAR( 20)
   DECLARE @cUserName   NVARCHAR( 18)
   DECLARE @cITFDBName  NVARCHAR( 20)
   DECLARE @cDataStream NVARCHAR( 10) = '5055'
   DECLARE @cSQL        NVARCHAR( MAX)
   DECLARE @cSQLParam   NVARCHAR( MAX)
   
   SET @nErrNo = 0
   
   IF @nFunc = 842 -- Ecomm packing
   BEGIN
      -- Check if this sku need verify serial no
      IF NOT EXISTS ( SELECT 1 FROM dbo.SKU WITH (NOLOCK) 
                      WHERE StorerKey = @cStorerKey 
                      AND   SKU = @cSKU 
                      AND   OVAS = '1')
         GOTO Quit
         
      SET @cITFDBName = rdt.RDTGetConfig( @nFunc, 'ITFDBName', @cStorerKey)

      IF @cITFDBName IN ('0', '')
      BEGIN    
         SET @nErrNo = 162901  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'NeedDTSITFName'  
         GOTO Quit  
      END   
      
      SELECT @cDropID = V_String6,
             @cUserName = UserName
      FROM RDT.RDTMOBREC WITH (NOLOCK)
      WHERE Mobile = @nMobile
      
      SELECT TOP 1 @cOrderkey = RTRIM(ISNULL(Orderkey,''))
      FROM rdt.rdtECOMMLog WITH (NOLOCK)  
      GROUP BY ToteNo, SKU , Status , AddWho, OrderKey 
      HAVING ToteNo = @cDropID  
      AND SKU = @cSKU  
      AND SUM(ExpectedQty) > SUM(ScannedQty) --+ 1 
      AND Status < '5'  
      AND AddWho = @cUserName
      ORDER BY Status Desc   
      
      BEGIN TRY
         SET @cSQL = 'EXEC ' + RTRIM( @cITFDBName) + '.dbo.isp_WOL_NONGIS_HK_GIVEX_SENDREQUEST ' +
            ' @cDataStream, @cStorerKey, @cOrderKey, @cSerialNo, @cSKU, @bdebug, ' + 
            ' @bSuccess OUTPUT, @nErr OUTPUT, @cOutErrMsg OUTPUT '

         SET @cSQLParam =
            '@cDataStream      NVARCHAR(10), ' +
            '@cStorerKey       NVARCHAR(15), ' +
            '@cOrderkey        NVARCHAR(10), ' +
            '@cSerialNo        NVARCHAR(30), ' +
            '@cSKU             NVARCHAR(20), ' +
            '@bdebug           INT,          ' +
            '@bSuccess         INT           OUTPUT, ' +
            '@nErr             INT           OUTPUT, ' +
            '@cOutErrMsg       NVARCHAR(250) OUTPUT  ' 

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @cDataStream, @cStorerKey, @cOrderkey, @cSerialNo, @cSKU, 0, @bSuccess OUTPUT, @nErr OUTPUT, @cOutErrMsg OUTPUT
         /*      
         EXEC HKDTSITF.dbo.isp_WOL_NONGIS_HK_GIVEX_SENDREQUEST
           @c_DataStream   = '5055'  
         , @c_StorerKey    = @cStorerKey
         , @c_OrderKey     = @cOrderkey
         , @c_SerialNumber = @cSerialNo
         , @c_SKU          = @cSKU
         , @b_debug        = 0
         , @b_Success      = @b_Success OUTPUT
         , @n_Err          = @n_Err OUTPUT
         , @c_OutErrMsg    = @c_OutErrMsg OUTPUT
         */
      END TRY      
      BEGIN CATCH    
         SET @nErrNo = 162902  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SendRequestFail'  
         GOTO Quit  
      END CATCH   
     
      IF ISNULL( @cOutErrMsg,'') <> 'SUCCESS'      
      BEGIN  
         SET @nErrNo = 162903  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid GiftCard'  
         GOTO Quit  
      END     
   END

Quit:

END


GO