SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_841RefNoInsLog01                                */
/* Copyright      : LF                                                  */
/*                                                                      */
/* Purpose: Look up loadkey from RefNo (pickslip no)                    */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author   Purposes                                   */
/* 2021-05-27  1.0  James    WMS-17077. Created                         */
/* 2022-09-21  1.1  yeekung  WMS-20327 Add orderkey (yeekung01)         */
/************************************************************************/

CREATE   PROC [RDT].[rdt_841RefNoInsLog01] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          NVARCHAR( 18),
   @nInputKey      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cRefNo         NVARCHAR( 20),
   @cToteNo        NVARCHAR( 20),
   @cWaveKey       NVARCHAR( 10),
   @cLoadKey       NVARCHAR( 10),
   @cSKU           NVARCHAR( 20),
   @cDropIDType    NVARCHAR( 10),
   @cUserName      NVARCHAR( 18),
   @cOrderkey      NVARCHAR( 10) OUTPUT,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT

) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nStep = 2
   BEGIN
      IF @nInputKey = 1
      BEGIN
         INSERT INTO rdt.rdtECOMMLog(Mobile, ToteNo, Orderkey, Sku, DropIDType, ExpectedQty, ScannedQty, AddWho, AddDate, EditWho, EditDate)
         SELECT TOP 1 @nMobile, @cToteNo, PK.Orderkey, PK.SKU, @cDropIDType, SUM(PK.Qty), 0, @cUserName, GETDATE(), @cUserName, GETDATE()
         FROM dbo.PICKDETAIL PK WITH (NOLOCK)
         JOIN dbo.Orders O WITH (NOLOCK) ON O.Orderkey = PK.Orderkey
         WHERE PK.PickSlipNo = @cRefNo
            AND PK.StorerKey = @cStorerKey
            AND PK.SKU = @cSKU
            AND PK.Status IN ( '0', '3')  AND PK.ShipFlag = '0'
            AND PK.CaseID = ''
            AND O.Type IN ('DTC', 'TMALL', 'NORMAL', 'COD', 'SS',
                           'EX', 'TMALLCN', 'NORMAL1', 'VIP', 'B2C')
            AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD', 'PENDCANC' )
            AND PK.Qty > 0
            AND ISNULL(O.TrackingNo ,'') <> ''   -- (james13)
            AND NOT EXISTS ( SELECT 1 FROM rdt.rdtECOMMLog RE WITH (NOLOCK)
                              WHERE RE.OrderKey = O.OrderKey
                              AND Status < '9'  )
         GROUP BY PK.OrderKey, PK.SKU

         IF @@ROWCOUNT = 0 -- No data inserted
         BEGIN
            SET @nErrNo = 168601
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'NoRecToProcess'
            GOTO QUIT
         END
      END
   END
END

QUIT:


GO