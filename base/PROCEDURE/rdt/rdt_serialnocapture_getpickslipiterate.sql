SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_SerialNoCapture_GetPickSlipIterate              */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Validation for Serial Number Capture function               */
/*          Called by rdtfnc_SerialNoCapture                            */
/*                                                                      */
/* Called from: 3                                                       */
/*    1. From PowerBuilder                                              */
/*    2. From scheduler                                                 */
/*    3. From others stored procedures or triggers                      */
/*    4. From interface program. DX, DTS                                */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* ??-???-2006 1.0  James    Created                                    */
/* 26-Oct-2006 1.1  MaryVong 1) Check if PickHeader.ExternOrderKey is   */
/*                              blank, retrieve based on OrderKey only  */
/*                           2) If pass-in @cSKU is NULL, check all sku */
/* 25-Oct-2006 1.2  Ung      3) Perfomance tunning                      */  
/* 02-Sep-2008 1.3  Vicky    Modify to cater for SQL2005 (Vicky01)      */       
/* 02-Dec-2009 1.4  Vicky    Revamp SP for the purpose of RDT to WMS    */
/*                           take out DBName from parameter (Vicky02)   */ 
/* 11-Jan-2010 1.5  Vicky    SOS#153915 - Add in SSCC checking (Vicky03)*/
/* 24-Feb-2012 1.6  Ung      SOS236331 Support key-in SerialNo.QTY      */
/*                           Clean up source                            */
/* 14-Sep-2017 1.7  James    WMS2988-Use ExtendedStatSP to calc serialno*/
/*                           qty (james01)                              */
/************************************************************************/

CREATE PROC [RDT].[rdt_SerialNoCapture_GetPickSlipIterate]
   @cPickSlipNo  NVARCHAR(10),
   @cSKU         NVARCHAR(20),
   @nSerialNoQTY INT OUTPUT, 
   @nPickQTY     INT OUTPUT, 
   @cCheckSSCC   NVARCHAR(1) = '0'
AS
BEGIN
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE 
      @cZone            NVARCHAR( 18),
      @cExternOrderKey  NVARCHAR( 20),
      @cOrderKey        NVARCHAR( 10),
      @cExtendedStatSP  NVARCHAR( 20),
      @cLotNo           NVARCHAR( 10),
      @cSQL             NVARCHAR(MAX),  
      @cSQLParam        NVARCHAR(MAX),  
      @cStorerKey       NVARCHAR( 15),
      @cLangCode        NVARCHAR( 3),
      @nFunc            INT,
      @nMobile          INT,
      @nStep            INT,
      @nInputKey        INT,
      @nErrNo           INT,
      @cErrMsg          NVARCHAR( 20)


   SELECT @nMobile = Mobile,
          @nFunc = Func,
          @cLangCode = Lang_Code,
          @nStep = Step,
          @nInputKey = InputKey,
          @cStorerKey = StorerKey
   FROM RDT.RDTMOBREC WITH (NOLOCK) 
   WHERE UserName = sUser_sName()

   -- Get PickSlip info
   SELECT @cZone = Zone, 
          @cExternOrderKey = ExternOrderKey, 
          @cOrderKey = OrderKey 
   FROM dbo.PickHeader WITH (NOLOCK) 
   WHERE PickHeaderKey = @cPickSlipNo

   SET @cExtendedStatSP = rdt.RDTGetConfig( @nFunc, 'ExtendedStatSP', @cStorerKey)
   IF @cExtendedStatSP = '0'  
      SET @cExtendedStatSP = ''

   IF @cExtendedStatSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedStatSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedStatSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cSKU, @cOrderKey, @cCheckSSCC, ' + 
            ' @cPickSlipNo, @cLotNo, @nSerialNoQTY OUTPUT, @nPickQTY OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
         SET @cSQLParam =
            '@nMobile        INT, ' +
            '@nFunc          INT, ' +
            '@cLangCode      NVARCHAR( 3),  ' +
            '@nStep          INT, ' +
            '@nInputKey      INT, ' +
            '@cStorerKey     NVARCHAR( 15), ' +
            '@cSKU           NVARCHAR( 20), ' +
            '@cOrderKey      NVARCHAR( 10), ' +
            '@cCheckSSCC     NVARCHAR( 1),  ' +
            '@cPickSlipNo    NVARCHAR( 10), ' +
            '@cLotNo         NVARCHAR( 10), ' +
            '@nSerialNoQTY   INT           OUTPUT, ' +
            '@nPickQTY       INT           OUTPUT, ' +
            '@nErrNo         INT           OUTPUT, ' + 
            '@cErrMsg        NVARCHAR( 20) OUTPUT'
            
           
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cSKU, @cOrderKey, @cCheckSSCC, 
            @cPickSlipNo, @cLotNo, @nSerialNoQTY OUTPUT, @nPickQTY OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT 
            
         IF @nErrNo <> 0 
            GOTO QUIT 
      
      END
   END 
   ELSE
   BEGIN
      -- Discrete pick slip
      IF @cOrderKey <> ''
      BEGIN
         SELECT @nPickQTY = SUM( PD.Qty) 
         FROM dbo.OrderDetail OD WITH (NOLOCK) 
            INNER JOIN dbo.PickDetail PD WITH (NOLOCK, INDEX(PickDetail_OrderDetStatus)) ON (OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber)
            INNER JOIN dbo.SKU S WITH (NOLOCK) ON (S.StorerKey = PD.StorerKey AND S.SKU = PD.SKU)
         WHERE OD.OrderKey = @cOrderKey
            AND S.SKU = CASE WHEN @cSKU IS NULL THEN S.SKU ELSE @cSKU END
            AND ((@cCheckSSCC <> '1') OR (@cCheckSSCC = '1' AND S.SUSR4 = 'SSCC'))
      
         SELECT @nSerialNoQTY = SUM( SN.QTY)
         FROM dbo.OrderDetail OD WITH (NOLOCK) 
            INNER JOIN dbo.SerialNo SN WITH (NOLOCK) ON (OD.OrderKey = SN.OrderKey AND OD.OrderLineNumber = SN.OrderLineNumber)
            INNER JOIN dbo.SKU S WITH (NOLOCK) ON (S.StorerKey = OD.StorerKey AND S.SKU = OD.SKU)
         WHERE OD.OrderKey = @cOrderKey
            AND S.SKU = CASE WHEN @cSKU IS NULL THEN S.SKU ELSE @cSKU END
            AND ((@cCheckSSCC <> '1') OR (@cCheckSSCC = '1' AND S.SUSR4 = 'SSCC'))
      END

      SET @nSerialNoQTY = ISNULL( @nSerialNoQTY, 0)
      SET @nPickQTY = ISNULL( @nPickQTY, 0)
   END

   QUIT:
END -- procedure

GO