SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_CreateVASWorkOrder                                    */
/* Copyright      : Maersk WMS                                                */
/*                                                                            */
/* Purpose: Create work order                                                 */
/*                                                                            */
/* Version: 1.2                                                               */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author      Purposes                                       */
/* 2024-02-28 1.0  NLT013       Created First Version (UWP-15257)             */
/* 2024-02-28 1.1  Dennis       VAS Modification (UWP-18854)                  */
/* 2024-08-15 1.2  LJQ006       Outbound VAS (FCR-657)                        */
/******************************************************************************/

CREATE PROCEDURE [rdt].[rdt_CreateVASWorkOrder] (
   @nFunc                INT,
   @nMobile              INT,
   @cLangCode            NVARCHAR( 3),
   @cStorerKey           NVARCHAR( 15),
   @cFacility            NVARCHAR( 5),

   @cReceiptKey          NVARCHAR( 10),
   @cReceiptLineNo       NVARCHAR( 5),
   @cOrderKey            NVARCHAR( 10),
   @cOrderLineNo         NVARCHAR( 5),
   @cFromID              NVARCHAR( 18), 
   @cPalletID            NVARCHAR( 18),  --pallet id for inbound or outbound
   @cGenerateCharges     NVARCHAR( 3),   -- Yes/No
   @cServiceType         NVARCHAR( 20),  --Service Type, e.g. LABEL PLT, RPLT IB PL
   @cSKU                 NVARCHAR( 20),  --SKU

   @cACTVASWO            NVARCHAR( 30),  --CODELKUP List name
   @nActionType          INT,            --1. Inbound    2. Outbound

   @nErrNo               INT                   OUTPUT,
   @cErrMsg              NVARCHAR( 20)         OUTPUT
) AS
BEGIN

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE
   @cUnit                NVARCHAR( 10),  --work type, e.g.PLT, CS
   @cReason              NVARCHAR( 10),  --Reason code, e.g. VAS
   @cWKOrderUdef02       NVARCHAR( 18),  --VAS for inbound or outbound, e.g. IVAS, OVAS

   @cKeyString           NVARCHAR( 25),
   @bSuccess             BIT,
   @nMaxLineNo           INT,
   @nMaxLineNoString     NVARCHAR( 5),

   @cExternWorkOrderKey   NVARCHAR( 10),
   @cExternLineNo         NVARCHAR( 5),

   @nRowCount            INT,
   @nTranCount           INT
   
   --Initialize error number and error message
   SET @nErrNo = 0;
   SET @cErrMsg = ''

   -- Validate StorerKey
   IF @cStorerKey = ''
   BEGIN
      SET @nErrNo = 211707
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Need StorerKey'
      GOTO Quit
   END

   -- Validate Facility
   IF @cFacility = ''
   BEGIN
      SET @nErrNo = 211708
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Need Facility'
      GOTO Quit
   END

   -- Validate ID
   IF @cPalletID = ''
   BEGIN
      SET @nErrNo = 211701
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Need ID'
      GOTO Quit
   END

   -- Validate VAS Code
   IF @cServiceType = ''
   BEGIN
      SET @nErrNo = 211705
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Need VAS Code'
      GOTO Quit
   END


   IF @nActionType = 1
   BEGIN
      --Get reason and unit 
      SELECT 
         @cUnit           = UDF02,
         @cReason         = UDF03,
         @cWKOrderUdef02  = code2
      FROM dbo.CODELKUP WITH(NOLOCK)
      WHERE Storerkey     = @cStorerKey
         AND LISTNAME     = @cACTVASWO
         AND Code         = @cServiceType
         AND UDF01        = @cFacility
         AND code2        = 'IVAS'

      SELECT @nRowCount = @@ROWCOUNT

      IF @nRowCount = 0
      BEGIN
         SET @nErrNo = 211706
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'VAS Code not Exist'
         GOTO Quit
      END
   END

   IF @nActionType = 2
   BEGIN
      SELECT 
         @cUnit           = UDF02,
         @cReason         = UDF03,
         @cWKOrderUdef02  = code2
      FROM dbo.CODELKUP WITH(NOLOCK)
      WHERE Storerkey     = @cStorerKey
         AND LISTNAME     = @cACTVASWO
         AND Code         = @cServiceType
         AND UDF01        = @cFacility
         AND code2        = 'OVAS'

      SELECT @nRowCount = @@ROWCOUNT

      IF @nRowCount = 0
      BEGIN
         SET @nErrNo = 211706
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'VAS Code not Exist'
         GOTO Quit
      END
   END
   
      
   

   --Create Inbound workorder
   IF @nActionType = 1
   BEGIN
      -- Validate ReceiptKey
      IF @cReceiptKey = ''
      BEGIN
         SET @nErrNo = 211709
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Need Receipt Key'
         GOTO Quit
      END

      SET @cExternWorkOrderKey = @cReceiptKey
      SET @cExternLineNo = @cReceiptLineNo
   END

   -- Outbound workorder situation
   IF @nActionType = 2
   BEGIN
      -- Validate OrderKey
      IF @cOrderKey = ''
      BEGIN
         SET @nErrNo = 211720
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Need Order Key'
         GOTO Quit
      END

      SET @cExternWorkOrderKey = @cOrderKey
      SET @cExternLineNo = @cOrderLineNo
   END

   --Check if the VAS work order already exists or not
   SELECT @nRowCount = COUNT(1)
   FROM dbo.WorkOrder wo WITH(NOLOCK)
   INNER JOIN dbo.WorkOrderDetail wod WITH(NOLOCK)
      ON wo.StorerKey     = wod.StorerKey
      AND wo.WorkOrderKey = wod.WorkOrderKey
   WHERE wo.Facility                                 = @cFacility
      AND wo.StorerKey                               = @cStorerKey
      AND ISNULL(wo.ExternWorkOrderKey, '-1')        = @cExternWorkOrderKey
      AND ISNULL(wod.ExternLineNo, '-1')             = @cExternLineNo
      AND ISNULL(wod.Sku, '-1')                      = @cSKU
      AND wod.Type                                   = @cServiceType
      AND ISNULL(wod.WkOrdUdef1, '-1')               = @cPalletID

   IF @nRowCount > 0
   BEGIN
      SET @nErrNo = 211710
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Duplicated VAS Action'
      GOTO Quit
   END

   SELECT @nTranCount = @@TRANCOUNT;
   IF @nTranCount = 0
      BEGIN TRANSACTION
   ELSE
      BEGIN TRANSACTION create_work_order

   BEGIN TRY
      IF NOT EXISTS(SELECT 1 
                     FROM dbo.WorkOrder wo WITH(NOLOCK) 
                     INNER JOIN dbo.WorkOrderDetail wod WITH(NOLOCK) 
                                 ON wod.StorerKey     = wo.StorerKey
                                 AND wod.WorkOrderKey = wo.WorkOrderKey 
                     WHERE wo.StorerKey                   = @cStorerKey 
                        AND wo.Facility                   = @cFacility 
                        AND ISNULL(wod.WkOrdUdef1, '-1')  = @cPalletID
                        AND wod.ExternWorkOrderKey        = @cExternWorkOrderKey
                        AND wod.ExternLineNo              = @cExternLineNo
                        AND wo.status = 0)
      BEGIN
         --Create work order
         EXECUTE nspg_getkey
            @KeyName       = 'WorkOrder' ,
            @fieldlength   = 10,    
            @keystring     = @cKeyString  Output,
            @b_success     = @bSuccess    Output,
            @n_err         = @nErrNo      Output,
            @c_errmsg      = @cErrMsg     Output,
            @b_resultset   = 0,
            @n_batch       = 1

         IF @nErrNo <> 0 OR @bSuccess <> 1
         BEGIN
            SET @nErrNo = 100654
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Getkey fail'
            GOTO Exception
         END

         --Insert Work Order Header
         INSERT INTO dbo.WorkOrder
            (
               WorkOrderKey,
               ExternWorkOrderKey,
               StorerKey, 
               Facility,
               GenerateCharges,
               Status,

               Type,
               Reason,
               WkOrdUdef1 -- Pallet ID
            )
         VALUES
            (
               @cKeyString,
               @cExternWorkOrderKey,
               @cStorerKey,
               @cFacility,
               @cGenerateCharges,
               0,
               
               '',
               '',
               @cPalletID
            )
      END
      ELSE 
      BEGIN
         -- two situations of work detail validation
         IF @nActionType = 1
         BEGIN
            SELECT @cKeyString = WorkOrderKey
            FROM dbo.WorkOrderDetail WITH(NOLOCK)
            WHERE ExternWorkOrderKey = @cReceiptKey
               AND ExternLineNo      = @cExternLineNo
               AND WkOrdUdef1        = @cPalletID
         END

         IF @nActionType = 2
         BEGIN
            SELECT @cKeyString = WorkOrderKey
            FROM dbo.WorkOrderDetail WITH(NOLOCK)
            WHERE ExternWorkOrderKey = @cOrderKey
               AND ExternLineNo      = @cOrderLineNo
               AND WkOrdUdef1        = @cPalletID
         END
      END

      IF @cKeyString IS NULL OR @cKeyString = ''
      BEGIN
         SET @nErrNo = 211714
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Generate WorkOrder Fail'
         ;THROW 51000, @cErrMsg, 1
      END

      SELECT @nMaxLineNo = ISNULL(MAX( TRY_CAST(WorkOrderLineNumber AS INT )), 0) + 1
      FROM dbo.WorkOrderDetail wod WITH(NOLOCK)
      WHERE WorkOrderKey = @cKeyString;

      SET @nMaxLineNoString = REPLICATE ('0', 5 - LEN (TRY_CAST (@nMaxLineNo AS NVARCHAR(3)) ) ) + TRY_CAST(@nMaxLineNo AS NVARCHAR(3)) 

      INSERT INTO dbo.WorkOrderDetail
         (
            WorkOrderKey,
            WorkOrderLineNumber,
            StorerKey, 
            ExternWorkOrderKey,
            ExternLineNo,
            Type,
            Reason,
            Unit,
            Sku,
            Qty,
            Status,
            WkOrdUdef1,
            WkOrdUdef2,
            WKOrdUdef3,
            price
         )
      VALUES
         (
            @cKeyString,
            @nMaxLineNoString,
            @cStorerKey,
            @cExternWorkOrderKey,
            @cExternLineNo,
            @cServiceType,
            @cReason,
            @cUnit,
            @cSKU,
            1,
            0,
            @cPalletID,
            @cWKOrderUdef02,
            @cFromID,
            0
         )
   END TRY
   BEGIN CATCH
      SET @nErrNo = 211714
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Generate WorkOrder Fail'
      GOTO Exception
   END CATCH

   GOTO Quit;

Exception:
   ROLLBACK TRANSACTION

Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRANSACTION 
END

GO