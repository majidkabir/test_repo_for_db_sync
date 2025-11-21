SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_840ExtUpd27                                     */
/* Copyright      : Maersk                                              */
/*                                                                      */  
/* Purpose: Trigger middleware sp when change carton                    */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 2023-05-10  1.0  James      WMS-22084. Created                       */
/* 2023-10-13  1.1  James      WMS-23401 Add update Pack Refno (james01)*/
/* 2024-06-18  1.2  James      WMS-24295 Allow confirm carton type      */
/*                             if same tote is scanned (james02)        */
/* 2024-11-08  1.3  PXL009     FCR-1118 Merged 1.2 from v0 branch       */
/************************************************************************/

CREATE   PROC [RDT].[rdt_840ExtUpd27] (
   @nMobile     INT,
   @nFunc       INT,
   @cLangCode   NVARCHAR( 3),
   @nStep       INT,
   @nInputKey   INT,
   @cStorerkey  NVARCHAR( 15),
   @cOrderKey   NVARCHAR( 10),
   @cPickSlipNo NVARCHAR( 10),
   @cTrackNo    NVARCHAR( 20),
   @cSKU        NVARCHAR( 20),
   @nCartonNo   INT,
   @cSerialNo   NVARCHAR( 30),
   @nSerialQTY  INT,
   @nErrNo      INT           OUTPUT,
   @cErrMsg     NVARCHAR( 20) OUTPUT
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @nTranCount           INT
   DECLARE @cBillToKey           NVARCHAR( 15)
   DECLARE @bSuccess             INT
   DECLARE @cAutoCalWGT          NVARCHAR( 1)
   DECLARE @cCode                NVARCHAR( 30)
   DECLARE @cTableName           NVARCHAR( 10)
   DECLARE @cColumnName          NVARCHAR( 20)
   DECLARE @cSQL                 NVARCHAR( MAX) = ''
   DECLARE @cSQLParam            NVARCHAR( MAX) = ''
   DECLARE @nQty                 INT
   DECLARE @fWeight              FLOAT = 0
   DECLARE @fCtnWeight           FLOAT = 0
   DECLARE @cCtnType             NVARCHAR( 10)
   DECLARE @fCartonLength        FLOAT
   DECLARE @fCartonWidth         FLOAT
   DECLARE @fCartonHeight        FLOAT
   DECLARE @nPickQty             INT
   DECLARE @nPackQty             INT
   DECLARE @curUpdPackInf        CURSOR
   DECLARE @nTempCartonNo        INT
   DECLARE @cUserName            NVARCHAR( 18)
   DECLARE @cDropID              NVARCHAR( 20)
   DECLARE @nCtnQty              INT   = 0

   SELECT
      @cUserName = UserName,
      @cDropID = V_CaseID
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_840ExtUpd27

   IF @nStep = 3
   BEGIN
      IF @nInputKey = 0  -- User try to confirm carton type
      BEGIN
         -- nothing scanned or continue from previous scanned tote
         IF NOT EXISTS (SELECT 1
                        FROM rdt.rdtTrackLog WITH (NOLOCK)
                        WHERE AddWho = @cUserName)
         BEGIN
            -- Check if packed something
            IF EXISTS( SELECT 1
                      FROM dbo.PACKDETAIL PD WITH (NOLOCK)
                      JOIN dbo.PACKHEADER PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)
                      WHERE PD.StorerKey = @cStorerkey
                      AND   PD.PickSlipNo = @cPickSlipNo
                      AND   PD.Qty > 0
                      AND   PD.RefNo2 = @cDropID)
            BEGIN
               SELECT
                  @cSKU = SKU,
                  @nCartonNo = CartonNo,
                  @nCtnQty = SUM( Qty)
               FROM dbo.PACKDETAIL WITH (NOLOCK)
               WHERE StorerKey = @cStorerkey
               AND   PickSlipNo = @cPickSlipNo
               AND   RefNo2 = @cDropID
               GROUP BY SKU, CartonNo

               INSERT INTO rdt.rdtTrackLog ( PickSlipNo, Mobile, UserName, Storerkey, Orderkey, TrackNo, SKU, Qty, CartonNo )
               VALUES (@cPickSlipNo, @nMobile, @cUserName, @cStorerkey, @cOrderKey, '', @cSKU, @nCtnQty, @nCartonNo  )

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 203804
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsLog Failed'
                  GOTO RollBackTran
               END
            END
         END
      END
   END

   IF @nStep = 4
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SET @cAutoCalWGT = rdt.RDTGetConfig( @nFunc, 'AUTOCALWGT', @cStorerKey)

         SELECT @cCode = Code
         FROM dbo.CODELKUP WITH (NOLOCK)
         WHERE ListName = 'AUTOCALWGT'
         AND   Storerkey = @cStorerkey

         SET @cTableName = LEFT( @cCode, CHARINDEX('.', @cCode) - 1)
         SET @cColumnName = SUBSTRING( @cCode, CHARINDEX('.', @cCode) + 1, LEN( @cCode))

         IF @cAutoCalWGT = '1' AND
            EXISTS( SELECT 1
            FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_NAME = @cTableName
               AND COLUMN_NAME = @cColumnName
               AND DATA_TYPE in ('INT', 'FLOAT', 'REAL'))
         BEGIN
            DECLARE @curSKU   CURSOR
            SET @curSKU= CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT SKU, SUM( Qty)
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo
            AND   CartonNo = @nCartonNo
            GROUP BY SKU
            OPEN @curSKU
            FETCH NEXT FROM @curSKU INTO @cSKU, @nQty
            WHILE @@FETCH_STATUS = 0
            BEGIN
               SET @cSQL =
                  ' SELECT @fWeight = ' + @cColumnName +
                  ' FROM dbo.' + @cTableName + ' WITH (NOLOCK) ' +
                  ' WHERE StorerKey = @cStorerKey ' +
                  ' AND SKU = @cSKU '
               SET @cSQLParam =
                  ' @cStorerKey     NVARCHAR(15), ' +
                  ' @cSKU           NVARCHAR(20), ' +
                  ' @fWeight        FLOAT OUTPUT '

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @cStorerKey,
                  @cSKU,
                  @fWeight     OUTPUT

               SET @fCtnWeight = @fCtnWeight + (( @fWeight * @nQty) * 1000)  -- Convert to grams

               FETCH NEXT FROM @curSKU INTO @cSKU, @nQty
            END
         END

         SELECT @cCtnType = CartonType
         FROM dbo.PackInfo WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo
         AND   CartonNo = @nCartonNo

         SELECT
            @fCartonLength = CZ.CartonLength,
            @fCartonWidth = CZ.CartonWidth,
            @fCartonHeight =  CZ.CartonHeight
         FROM dbo.CARTONIZATION CZ WITH (NOLOCK)
         JOIN dbo.STORER ST WITH (NOLOCK) ON ( CZ.CartonizationGroup = ST.CartonGroup)
         WHERE ST.StorerKey = @cStorerkey
         AND   CZ.CartonType = @cCtnType

         UPDATE dbo.PackInfo SET
            WEIGHT = @fCtnWeight,
            Length = @fCartonLength,
            Width = @fCartonWidth,
            Height = @fCartonHeight,
            EditWho = SUSER_SNAME(),
            EditDate = GETDATE()
         WHERE PickSlipNo = @cPickSlipNo
         AND   CartonNo = @nCartonNo

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 203801
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd Wgt Err'
            GOTO RollBackTran
         END

         SELECT @cBillToKey = BillToKey
         FROM dbo.ORDERS WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey

         -- Create a dummy label and a cartontrack record
         IF NOT EXISTS ( SELECT 1
                         FROM dbo.CODELKUP WITH (NOLOCK)
                         WHERE LISTNAME = 'LVSPLTCUST'
                         AND   Code = @cBillToKey
                         AND   Short = '1'
                         AND   Storerkey = @cStorerkey)
         BEGIN
            EXEC [dbo].[isp_Carrier_Middleware_Interface]
                 @c_OrderKey    = @cOrderKey
               , @c_Mbolkey     = ''
               , @c_FunctionID  = @nFunc
               , @n_CartonNo    = @nCartonNo
               , @n_Step        = @nStep
               , @b_Success     = @bSuccess  OUTPUT
               , @n_Err         = @nErrNo    OUTPUT
               , @c_ErrMsg      = @cErrMsg   OUTPUT

            IF @bSuccess = 0
            BEGIN
               SET @nErrNo = 203802
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Exec ITF Fail'
               GOTO RollBackTran
            END
         END

         SELECT @nPickQty = ISNULL( SUM( Qty), 0)
         FROM PickDetail WITH (NOLOCK)
         WHERE Orderkey = @cOrderkey
         AND Storerkey = @cStorerkey

         SELECT @nPackQty = ISNULL( SUM( PD.Qty), 0)
         FROM dbo.PackDetail PD WITH (NOLOCK)
         JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)
         WHERE PH.PickSlipNo = @cPickSlipNo

         IF @nPickQty = @nPackQty AND
         NOT EXISTS ( SELECT 1 FROM dbo.PackInfo WITH (NOLOCK)
                      WHERE PickSlipNo = @cPickSlipNo
                      AND   ISNULL( Refno, '') = 'Y')
         BEGIN
            UPDATE dbo.PackInfo SET
               RefNo = 'Y',
               EditWho = SUSER_SNAME(),
               EditDate = GETDATE()
            WHERE PickSlipNo = @cPickSlipNo
            AND   CartonNo = @nCartonNo

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 203803
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd PackInf Er'
               GOTO RollBackTran
            END
         END
      END
   END

   GOTO Quit

   RollBackTran:
         ROLLBACK TRAN rdt_840ExtUpd27
   Quit:
      WHILE @@TRANCOUNT > @nTranCount
         COMMIT TRAN

GO