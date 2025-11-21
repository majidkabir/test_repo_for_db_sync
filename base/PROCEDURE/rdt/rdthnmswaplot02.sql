SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdtHnMSwapLot02                                     */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: H&M JP swap lot logic                                       */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 10-Oct-2015 1.0  James       SOS353558 Created                       */
/* 25-Jan-2018 1.1  James       WMS3352-Add GenLabelNo_SP (james01)     */
/* 19-04-2018  1.2  Ung         WMS-4589 Add not mix L12 in a carton    */
/* 20-Nov-2019 1.3  James       WMS-11171 Display all error msg         */
/*                              in msgqueue (james01)                   */
/* 16-Apr-2021 1.4  James       WMS-16024 Standarized use of TrackingNo */
/*                              (james02)                               */
/* 17-Aug-2022 1.5  James       WMS-20442 Add scanned barcode to        */
/*                              PackDetail.LottableValue (james03)      */
/*                              Comment assign tracking no              */
/************************************************************************/

CREATE   PROC [RDT].[rdtHnMSwapLot02] (
   @n_Mobile         INT, 
   @c_Storerkey      NVARCHAR( 15), 
   @c_OrderKey       NVARCHAR( 10), 
   @c_TrackNo        NVARCHAR( 20), 
   @c_PickSlipNo     NVARCHAR( 10), 
   @n_CartonNo       INT, 
   @c_LOC            NVARCHAR( 10), 
   @c_ID             NVARCHAR( 18), 
   @c_SKU            NVARCHAR( 20), 
   @c_Lottable01     NVARCHAR( 18), 
   @c_Lottable02     NVARCHAR( 18), 
   @c_Lottable03     NVARCHAR( 18), 
   @d_Lottable04     DATETIME, 
   @d_Lottable05     DATETIME, 
   @c_Barcode        NVARCHAR( 40), 
   @b_Success        INT = 1  OUTPUT,
   @n_ErrNo          INT      OUTPUT, 
   @c_ErrMsg         NVARCHAR(250) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE 
           @n_ExpectedQty           INT, 
           @n_PackedQty             INT, 
           @c_LabelNo               NVARCHAR( 20), 
           @c_LoadKey               NVARCHAR( 10), 
           @c_Route                 NVARCHAR( 10), 
           @c_ConsigneeKey          NVARCHAR( 15), 
           @c_UserName              NVARCHAR( 18), 
           @c_CurLabelNo            NVARCHAR( 20), 
           @c_CurLabelLine          NVARCHAR( 5),     
           @c_TargetPickDetailKey   NVARCHAR( 10), 
           @c_TargetLot             NVARCHAR( 10), 
           @c_TargetID              NVARCHAR( 18), 
           @c_NewID                 NVARCHAR( 18), 
           @c_NewLOT                NVARCHAR( 10), 
           @c_Lot                   NVARCHAR( 10), 
           @c_CtnType               NVARCHAR( 10), 
           @c_Shipperkey            NVARCHAR( 15), 
           @c_TempCaseID            NVARCHAR( 20), 
           @n_err                   INT, 
           @c_LangCode              NVARCHAR( 3), 
           @c_PickDetailKey         NVARCHAR( 10), 
           @c_CarrierName           NVARCHAR( 30), 
           @c_KeyName               NVARCHAR( 30), 
           @nTranCount              INT, 
           @nLLI_Qty                INT, 
           @nPD_Qty                 INT, 
           @n_Continue              INT, 
           @n_SwapLot               INT, 
           @n_PickQty               INT, 
           @n_PackQty               INT,
           @n_Func                  INT,
           @n_Step                  INT,
           @n_InputKey              INT,
           @c_SQLStatement          NVARCHAR(2000),
           @c_SQLParms              NVARCHAR(2000),
           @c_GenLabelNo_SP         NVARCHAR( 20)

   DECLARE @c_ErrMsg1       NVARCHAR( 20), 
           @c_ErrMsg2       NVARCHAR( 20), 
           @c_ErrMsg3       NVARCHAR( 20), 
           @c_ErrMsg4       NVARCHAR( 20), 
           @c_ErrMsg5       NVARCHAR( 20) 
   
   DECLARE @n_MsgQErrNo     INT
   DECLARE @n_MsgQErrMsg    NVARCHAR( 20)

   DECLARE @c_DropID        NVARCHAR( 20)
   
   SET @n_ErrNo = 0
   SET @n_SwapLot = 1

   SELECT @n_Func = Func, 
          @n_Step = Step, 
          @n_InputKey = InputKey,
          @c_DropID = V_CaseID
   FROM RDT.RDTMOBREC WITH (NOLOCK) 
   WHERE Mobile = @n_Mobile

   IF ISNULL( @c_OrderKey, '') = ''
   BEGIN
      SET @n_ErrNo = 57551    
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'Invalid Order'    
      GOTO Quit_WithoutTran
   END

   IF ISNULL( @c_SKU, '') = '' 
   BEGIN
      SET @n_ErrNo = 57552    
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'Invalid SKU'    
      GOTO Quit_WithoutTran
   END

   IF ISNULL( @c_Lottable02, '') = '' 
   BEGIN
      SET @n_ErrNo = 57553    
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'Invalid LOT02'    
      GOTO Quit_WithoutTran
   END

   IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK) 
                   WHERE StorerKey = @c_Storerkey
                   AND   OrderKey = @c_OrderKey
                   AND   SKU = @c_SKU
                   AND   [Status] < '9')
   BEGIN
      SET @n_ErrNo = 57554    
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'SKU NOT IN ORD'    
      GOTO Quit_WithoutTran
   END

   SELECT @c_UserName = UserName FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE Mobile = @n_Mobile

   -- If it is not Sales type order then no need swap lot. Check validity of 2D barcode
   IF NOT EXISTS ( SELECT 1 FROM dbo.CODELKUP C WITH (NOLOCK) 
                   JOIN dbo.Orders O WITH (NOLOCK) ON (C.Code = O.Type AND C.StorerKey = O.StorerKey)
                   WHERE C.ListName = 'HMORDTYPE'
                   AND   C.Short = 'S'
                   AND   O.OrderKey = @c_Orderkey
                   AND   O.StorerKey = @c_StorerKey)
   BEGIN
      SET @n_SwapLot = 0
      
      -- SKU + Lottable02 must match pickdetail for this orders
      IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK) 
                      JOIN dbo.LotAttribute LA WITH (NOLOCK) ON PD.LOT = LA.LOT
                      WHERE PD.StorerKey = @c_Storerkey
                      AND   PD.OrderKey = @c_OrderKey
                      AND   PD.SKU = @c_SKU
                      AND   PD.Status < '9'
                      AND   PD.QtyMoved < PD.QTY
                      AND   LA.Lottable02 = @c_Lottable02)
      BEGIN
         SET @n_ErrNo = 57555    
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'Invalid Label'    
         GOTO Quit_WithoutTran
      END

      -- Get carton info
      DECLARE @c_UPC NVARCHAR(30)
      SET @c_UPC = ''
      SELECT TOP 1 @c_UPC = UPC FROM PackDetail WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo AND CartonNo = @n_CartonNo
      
      -- Get lottable12 of the carton
      IF @c_UPC <> ''
      BEGIN
         DECLARE @c_Carton_L12 NVARCHAR( 30)
         DECLARE @c_Scan_L12 NVARCHAR( 30)
         
         SET @c_Carton_L12 = SUBSTRING( @c_UPC, 22, 6) 
         SET @c_Scan_L12 = substring( @c_Lottable02, 7, 6) 
            
         -- Check different lottable12 (HMOrderNumber)
         IF @c_Carton_L12 <> @c_Scan_L12
         BEGIN
            SET @n_ErrNo = 57580    
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'Diff HMOrder'    
            GOTO Quit_WithoutTran
         END
      END
   END

   -- If it is sales orders and multiple parcels/carton
   IF @n_SwapLot = 1 AND @n_CartonNo > 1
   BEGIN
      -- If it is sales orders and is COD type then not allow to have multiple carton
      IF EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK) 
                  WHERE OrderKey = @c_Orderkey
                  AND   StorerKey = @c_StorerKey
                  AND   [Type] = 'COD')
      BEGIN
         SET @n_ErrNo = 57556    
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'COD Orders'    
         GOTO Quit_WithoutTran
      END

      SELECT @c_Shipperkey = Shipperkey
      FROM dbo.Orders WITH (NOLOCK) 
      WHERE OrderKey = @c_Orderkey
      AND   StorerKey = @c_StorerKey
   
      SELECT @c_CtnType = CartonType
      FROM dbo.PackInfo WITH (NOLOCK) 
      WHERE PickSlipNo = @c_PickSlipNo
      AND   CartonNo = 1   -- Letter service only 1 carton
      
      IF EXISTS ( SELECT 1
                  FROM dbo.CODELKUP WITH (NOLOCK)
                  WHERE ListName = 'HMCARTON'
                  AND   StorerKey = @c_StorerKey
                  AND   Short = @c_CtnType
                  AND   UDF01 = @c_Shipperkey
                  AND   UDF02 = 'LETTER')
      BEGIN
         SET @n_ErrNo = 57557    
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'Letter Service'    
         GOTO Quit_WithoutTran
      END
   END

   SET @n_ExpectedQty = 0    
   SELECT @n_ExpectedQty = ISNULL(SUM(Qty), 0) FROM dbo.PickDetail WITH (NOLOCK)    
   WHERE Orderkey = @c_Orderkey    
   AND   Storerkey = @c_StorerKey    
   AND   [Status] < '9'    
   AND   SKU = @c_SKU
    
   SET @n_PackedQty = 0    
   SELECT @n_PackedQty = ISNULL(SUM(Qty), 0) FROM RDT.rdtTrackLog WITH (NOLOCK)    
   WHERE Orderkey = @c_Orderkey    
   AND   Storerkey = @c_StorerKey    
   AND   [Status] < '9'
   AND   SKU = @c_SKU

   IF (@n_PackedQty + 1) > @n_ExpectedQty 
   BEGIN
      SET @n_ErrNo = 57558
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'SKU OVERPACKED'
      GOTO Quit_WithoutTran
   END

   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  -- Begin our own transaction  
   SAVE TRAN rdtHnMSwapLot02 -- For rollback or commit only our own transaction  

   IF @n_SwapLot = 1
   BEGIN
      SET @c_TempCaseID = RTRIM( @c_PickSlipNo) + CAST( @n_CartonNo AS NVARCHAR( 2))
      
      -- For H&M, 1 orders only have 1 lottable03. STD for normal cust order. BLO for move order
      SELECT TOP 1 @c_Lottable03 = Lottable03 
      FROM dbo.OrderDetail WITH (NOLOCK) 
      WHERE StorerKey = @c_StorerKey
      AND   OrderKey = @c_Orderkey
      AND   SKU = @c_SKU
      
      IF NOT EXISTS ( 
         SELECT 1
         FROM dbo.LOTXLOCXID LLI WITH (NOLOCK) 
         JOIN dbo.LotAttribute LA WITH (NOLOCK) ON LLI.LOT = LA.LOT 
         WHERE LLI.Storerkey = @c_StorerKey    
         AND   LLI.SKU = @c_SKU
         AND   LA.Lottable02 = @c_Lottable02
         AND   LA.Lottable03 = @c_Lottable03
         AND   EXISTS ( SELECT 1 FROM PickDetail PD WITH (NOLOCK) WHERE PD.SKU = LLI.SKU AND PD.OrderKey = @c_Orderkey))
      BEGIN
         SET @n_ErrNo = 57560
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'NOT LOT 2 SWAP'
         GOTO RollBackTran
      END
         
      DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
      SELECT LLI.LOC
      FROM dbo.LOTXLOCXID LLI WITH (NOLOCK) 
      JOIN dbo.LotAttribute LA WITH (NOLOCK) ON LLI.LOT = LA.LOT 
      WHERE LLI.Storerkey = @c_StorerKey    
      AND   LLI.SKU = @c_SKU
      AND   LA.Lottable02 = @c_Lottable02
      AND   LA.Lottable03 = @c_Lottable03
      AND   EXISTS ( SELECT 1 FROM PickDetail PD WITH (NOLOCK) WHERE PD.SKU = LLI.SKU AND PD.OrderKey = @c_Orderkey)
      ORDER BY 1
      OPEN CUR_LOOP
      FETCH NEXT FROM CUR_LOOP INTO @c_LOC
      WHILE @@FETCH_STATUS <> - 1 
      BEGIN
         SET @n_Continue = 1
         
         SET @c_PickDetailKey = ''
         SELECT TOP 1 @c_PickDetailKey = PD.PickDetailKey 
         FROM dbo.PickDetail PD WITH (NOLOCK) 
         JOIN dbo.LotAttribute LA WITH (NOLOCK) ON PD.LOT = LA.LOT
         WHERE PD.Orderkey = @c_Orderkey    
         AND   PD.Storerkey = @c_Storerkey    
         AND   PD.Status < '9'
         AND   PD.SKU = @c_SKU
         AND   PD.LOC = @c_LOC
         AND   QtyMoved = 0
         AND   LA.Lottable02 = @c_Lottable02

         -- If exists same lottable with same orderkey + same sku & enough qty in same lot02 no need swap
         IF ISNULL( @c_PickDetailKey, '') <> '' AND (@n_ExpectedQty >= @n_PackedQty + 1)
         BEGIN
            -- Update qtymoved to prevent this line to be swapped again
            UPDATE PickDetail WITH (ROWLOCK) SET 
               QtyMoved = 1, 
               CaseID = @c_TempCaseID, 
               Trafficcop = NULL
            WHERE PickDetailKey = @c_PickDetailKey
            
            IF @@ERROR <> 0    
            BEGIN    
               SET @n_ErrNo = 57561    
               SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'UPDPKDET Failed'    
               SET @n_Continue = 3
            END    
            BREAK
         END

         -- If not exists same SKU, same lot03 in same location then no swap 
         IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK) 
                         JOIN dbo.LotAttribute LA WITH (NOLOCK) ON PD.LOT = LA.LOT
                         WHERE PD.Storerkey = @c_StorerKey    
                         AND   PD.Status < '9'
                         AND   PD.SKU = @c_SKU
                         AND   PD.LOC = @c_LOC
                         AND   LA.Lottable03 = @c_Lottable03
                         AND   PD.QtyMoved = 0)
         BEGIN
            -- Look in inventory
            IF NOT EXISTS ( SELECT LLI.LOT 
                            FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
                            JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
                            WHERE LLI.StorerKey = @c_StorerKey
                            AND   LLI.SKU = @c_SKU
                            AND   LLI.LOC = @c_LOC      
                            AND  (LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked) > 0
                            AND   LA.Lottable03 = @c_Lottable03)
            BEGIN
               SET @n_ErrNo = 57562 
               SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'NO LOT 2 SWAP'
               SET @n_Continue = 3
            END
         END

         IF @n_Continue = 1
         BEGIN
            IF EXISTS ( SELECT 1 FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
                        JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
                        WHERE LLI.StorerKey = @c_StorerKey
                        AND   LLI.SKU = @c_SKU
                        AND   LLI.LOC = @c_LOC  
                        AND   LA.Lottable02 = @c_Lottable02
                        AND   LA.Lottable03 = @c_Lottable03    
                        HAVING   ISNULL( SUM(LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked), 0) = 0)
            BEGIN
               IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK) 
                               JOIN dbo.LotAttribute LA WITH (NOLOCK) ON PD.LOT = LA.LOT
                               WHERE PD.Storerkey = @c_StorerKey    
                               AND   PD.Status < '9'
                               AND   PD.SKU = @c_SKU
                               AND   PD.LOC = @c_LOC
                               AND   LA.Lottable02 = @c_Lottable02
                               AND   LA.Lottable03 = @c_Lottable03
                               AND   PD.QtyMoved = 0)
               BEGIN
                  SET @n_ErrNo = 57563 
                  SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'NO LOT 2 SWAP'
                  SET @n_Continue = 3
               END
            END
         END

         IF @n_Continue = 1
         BEGIN 
            -- Only sales orders (S), same loc & same lot03 can swap
            SET @c_PickDetailKey = '' 
            SET @c_TargetPickDetailKey = ''
            SET @c_Lot = ''
            SET @c_TargetLot = ''

            -- Searching for pickdetail line to swap
            SELECT TOP 1 @c_PickDetailKey = PD.PickDetailKey, @c_Lot = PD.Lot, @c_ID = PD.ID 
            FROM dbo.PickDetail PD WITH (NOLOCK) 
            JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
            WHERE PD.Orderkey = @c_Orderkey    
            AND   PD.Storerkey = @c_StorerKey    
            AND   PD.Loc = @c_LOC
            AND   PD.SKU = @c_SKU
            AND   PD.QtyMoved = 0   -- not been swapped before
            AND   PD.Status = '0'
            AND   LA.Lottable03 = @c_Lottable03

            IF @@ROWCOUNT = 0
            BEGIN
               SET @n_ErrNo = 57564 
               SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'NO LOT 2 SWAP'
               SET @n_Continue = 3
            END

            IF @n_Continue = 1
            BEGIN
               -- Searching target PickDetail with same sku, loc & lottable03 
               SELECT TOP 1 
                      @c_TargetPickDetailKey = PD.PickDetailKey, @c_TargetLot = PD.Lot, @c_TargetID = PD.ID 
               FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT AND PD.SKU = LA.SKU)
               WHERE  PD.StorerKey = @c_StorerKey
                  AND PD.SKU = @c_SKU
                  AND PD.LOC = @c_LOC
                  AND PD.Status = '0'
                  AND PD.QtyMoved = 0
                  AND PD.Orderkey <> @c_Orderkey
                  AND LA.Lottable02 = @c_Lottable02    -- (james01)
                  AND LA.Lottable03 = @c_Lottable03

               -- If can find other pickdetail to swap
               IF ISNULL(RTRIM(@c_TargetPickDetailKey), '') <> ''
               BEGIN
                  -- Swap original lot 
                  UPDATE PickDetail WITH (ROWLOCK) SET 
                     Lot = @c_TargetLot, 
                     ID = @c_TargetID, 
                     QtyMoved = 1, 
                     CaseID = @c_TempCaseID,
                     Trafficcop = NULL
                  WHERE PickDetailKey = @c_PickDetailKey

                  IF @@ERROR <> 0
                  BEGIN
                     SET @n_ErrNo = 57565
                     SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'SWAP LOT FAIL'
                     SET @n_Continue = 3
                     BREAK
                  END
                     
                  -- Swap target lot
                  UPDATE PickDetail WITH (ROWLOCK) SET 
                     Lot = @c_Lot, 
                     ID = @c_ID, 
                     Trafficcop = NULL
                  WHERE PickDetailKey = @c_TargetPickDetailKey

                  IF @@ERROR <> 0
                  BEGIN
                     SET @n_ErrNo = 57566
                     SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'SWAP LOT FAIL'
                     SET @n_Continue = 3
                     BREAK
                  END
                  
                  BREAK -- only need swap 1 qty
               END
               -- Cannot find other pickdetail to swap then look in inventory balance
               ELSE
               BEGIN
                  SET @c_NewLOT = ''

                  SELECT TOP 1 @c_NewLOT  = LLI.LOT, @c_NewID = ID 
                  FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
                  JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
                  WHERE LLI.StorerKey = @c_StorerKey
                  AND   LLI.SKU = @c_SKU
                  AND   LLI.LOC = @c_LOC      
                  AND  (LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked) > 0
                  AND   LA.Lottable02 = @c_Lottable02    -- (james01)
                  AND   LA.Lottable03 = @c_Lottable03

                  IF ISNULL( @c_NewLOT, '') <> ''
                  BEGIN
                     UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
                        Lot = @c_NewLOT, 
                        ID = @c_NewID, 
                        QtyMoved = 1, 
                        CaseID = @c_TempCaseID 
                     WHERE PickDetailKey = @c_PickDetailKey

                     IF @@ERROR <> 0
                     BEGIN
                        SET @n_ErrNo = 57567
                        SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'SWAP LOT FAIL'
                        set @n_Continue = 3
                     END
                     BREAK
                  END
                  ELSE
                  BEGIN
                     SET @n_ErrNo = 57568
                     SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'NO INV 2 SWAP'
                     SET @n_Continue = 3
                  END
               END
            END
         END

         FETCH NEXT FROM CUR_LOOP INTO @c_LOC
      END
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP
      
      IF @n_Continue = 3
         GOTO RollBackTran
         
      IF @n_Continue = 1
      BEGIN
         SET @n_ErrNo = 0    
         SET @c_ErrMsg = ''
      END
   END   -- End of @n_Swap = 1
   
   -- Insert pack here
   IF EXISTS (SELECT 1 FROM rdt.rdtTrackLog WITH (NOLOCK)    
              WHERE PickSlipNo = @c_PickSlipNo    
              AND Storerkey = @c_Storerkey     
              AND CartonNo = @n_CartonNo    
              AND UserName = @c_UserName    
              AND SKU = @c_SKU)   -- can scan many sku into 1 carton    
   BEGIN    
      UPDATE rdt.rdtTrackLog WITH (ROWLOCK) SET     
         Qty = ISNULL(Qty, 0) + 1,    
         EditWho = @c_UserName,    
         EditDate = GetDate()    
      WHERE PickSlipNo = @c_PickSlipNo    
      AND Storerkey = @c_Storerkey     
      AND CartonNo = @n_CartonNo    
      AND UserName = @c_UserName    
      AND SKU = @c_SKU    
 
      IF @@ERROR <> 0    
      BEGIN    
         SET @n_ErrNo = 57569    
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'UpdLog Failed'    
         EXEC rdt.rdtSetFocusField @n_Mobile, 6    
         GOTO RollBackTran    
      END    
   END    
   ELSE    
   BEGIN    
      INSERT INTO rdt.rdtTrackLog ( PickSlipNo, Mobile, UserName, Storerkey, Orderkey, TrackNo, SKU, Qty, CartonNo )    
      VALUES (@c_PickSlipNo, @n_Mobile, @c_UserName, @c_Storerkey, @c_Orderkey, @c_TrackNo, @c_SKU, 1, @n_CartonNo  )    
 
       IF @@ERROR <> 0    
       BEGIN    
         SET @n_ErrNo = 57570    
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'InsLog Failed'    
         EXEC rdt.rdtSetFocusField @n_Mobile, 6    
         GOTO RollBackTran    
      END    
   END    

   -- Create PackHeader if not yet created    
   IF NOT EXISTS (SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo)    
   BEGIN    
      SELECT @c_LoadKey = ISNULL(RTRIM(LoadKey),'')    
           , @c_Route = ISNULL(RTRIM(Route),'')    
           , @c_ConsigneeKey = ISNULL(RTRIM(ConsigneeKey),'')    
      FROM dbo.Orders WITH (NOLOCK)    
      WHERE Orderkey = @c_Orderkey    
          
      INSERT INTO dbo.PACKHEADER    
      (PickSlipNo, StorerKey, OrderKey, LoadKey, Route, ConsigneeKey, OrderRefNo, TtlCnts, [STATUS])     
      VALUES    
      (@c_PickSlipNo, @c_Storerkey, @c_Orderkey, @c_LoadKey, @c_Route, @c_ConsigneeKey, '', 0, '0')     
          
       IF @@ERROR <> 0    
       BEGIN    
         SET @n_ErrNo = 57571    
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'InsPKHDR Failed'    
         EXEC rdt.rdtSetFocusField @n_Mobile, 6    
         GOTO RollBackTran    
      END    
   END    
   /* commented because now HM uses interface to get tracking no
      RDT pack only use temp running no as tracking no/label no
      IML will then update back packdetail.labelno and pickdetail.caseid
   -- If customer order (only customer order can swap lot)
   IF @n_SwapLot = 1
   BEGIN
      -- Get tracking no. Customer order can have > 1 carton
      -- If 1st carton then get the tracking no from orders.userdefine04
      IF @n_CartonNo = 1
      BEGIN
         --SELECT @c_TrackNo = UserDefine04
         SELECT @c_TrackNo = TrackingNo   -- (james02)
         FROM dbo.Orders WITH (NOLOCK) 
         WHERE StorerKey = @c_StorerKey
         AND   OrderKey = @c_OrderKey

         IF ISNULL( @c_TrackNo, '') = ''
         BEGIN    
            SET @n_ErrNo = 57572    
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'NO TRACKING #'    
            EXEC rdt.rdtSetFocusField @n_Mobile, 6    
            GOTO RollBackTran    
         END    
      END
      ELSE
      BEGIN
         -- Check if same carton exists before. Diff sku can scan into same carton    
         IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)    
                    WHERE StorerKey = @c_Storerkey    
                    AND PickSlipNo = @c_PickSlipNo    
                    AND CartonNo = @n_CartonNo)    
         BEGIN    
           /** get new available pre-paid tracking number **/
            SELECT @c_CarrierName = Code, 
                   @c_KeyName = UDF05
            FROM dbo.Codelkup WITH (NOLOCK)
            WHERE Listname = 'HMCourier' 
            AND   Long = 'NORMAL' 
            AND   StorerKey = @c_Storerkey

            SELECT @c_TrackNo = MIN( TrackingNo)
            FROM dbo.CartonTrack WITH (NOLOCK)
            WHERE CarrierName = @c_CarrierName 
            AND   Keyname = @c_KeyName 
            AND   ISNULL( CarrierRef2, '') = ''

            IF ISNULL( @c_TrackNo, '') = ''
            BEGIN    
               SET @n_ErrNo = 57573    
               SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'NO TRACKING #'    
               EXEC rdt.rdtSetFocusField @n_Mobile, 6    
               GOTO RollBackTran    
            END 
         
           /**update cartontrack **/
            UPDATE dbo.CartonTrack WITH (ROWLOCK) SET 
               LabelNo = @c_OrderKey,  
               Carrierref2 = 'GET'
            WHERE CarrierName = @c_CarrierName 
            AND   Keyname = @c_KeyName 
            AND   CarrierRef2 = ''
            AND   TrackingNo = @c_TrackNo

            IF @@ERROR <> 0
            BEGIN    
               SET @n_ErrNo = 57574    
               SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'ASSIGN TRACK# FAIL'    
               EXEC rdt.rdtSetFocusField @n_Mobile, 6    
               GOTO RollBackTran    
            END 
         END
         ELSE
         BEGIN
            SELECT TOP 1 @c_TrackNo = LabelNo
            FROM dbo.PackDetail WITH (NOLOCK)    
            WHERE StorerKey = @c_Storerkey    
            AND PickSlipNo = @c_PickSlipNo    
            AND CartonNo = @n_CartonNo
         END
      END

      -- Update pickdetail.caseid = tracking no (Only for customer order)
      IF ISNULL( @c_TrackNo, '') <> ''
      BEGIN
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
            CaseID = @c_TrackNo, 
            TrafficCop = NULL
         WHERE StorerKey = @c_StorerKey
         AND   OrderKey = @c_OrderKey
         AND   QtyMoved = 1
         AND   CaseID = RTRIM( @c_PickSlipNo) + CAST( @n_CartonNo AS NVARCHAR( 2))

         IF @@ERROR <> 0
         BEGIN    
            SET @n_ErrNo = 57575    
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'ASSIGN TRACK# FAIL'    
            EXEC rdt.rdtSetFocusField @n_Mobile, 6    
            GOTO RollBackTran    
         END 
      END
   END
   */
   -- Update PackDetail.Qty if it is already exists    
   IF EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)    
              WHERE StorerKey = @c_Storerkey    
              AND PickSlipNo = @c_PickSlipNo    
              AND CartonNo = @n_CartonNo    
              AND SKU = @c_SKU
              AND UPC = @c_Barcode) -- different 2D barcode split to different packdetail line
   BEGIN    
      UPDATE dbo.PackDetail WITH (ROWLOCK) SET     
         Qty = Qty + 1,    
         EditDate = GETDATE(),    
         EditWho = 'rdt.' + sUser_sName()    
      WHERE StorerKey = @c_Storerkey    
      AND PickSlipNo = @c_PickSlipNo    
      AND CartonNo = @n_CartonNo    
      AND SKU = @c_SKU    
      AND UPC = @c_Barcode
          
      IF @@ERROR <> 0    
      BEGIN    
         SET @n_ErrNo = 57576    
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'UPDPKDET Failed'    
         EXEC rdt.rdtSetFocusField @n_Mobile, 6    
         GOTO RollBackTran    
      END    
   END    
   ELSE     -- Insert new PackDetail    
   BEGIN    
      -- Check if same carton exists before. Diff sku can scan into same carton    
      IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)    
                 WHERE StorerKey = @c_Storerkey    
                 AND PickSlipNo = @c_PickSlipNo    
                 AND CartonNo = @n_CartonNo)    
      BEGIN    
         -- Set label no = tracking no (Only for customer orders)
         IF @n_SwapLot = 1
         BEGIN
            -- Get new LabelNo    
            EXECUTE isp_GenUCCLabelNo    
                     @c_Storerkey,    
                     @c_LabelNo    OUTPUT,    
                     @b_Success     OUTPUT,    
                     @n_ErrNo       OUTPUT,    
                     @c_ErrMsg      OUTPUT    
    
            IF @b_Success <> 1    
            BEGIN    
               SET @n_ErrNo = 57577    
               SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'GET LABEL Fail'    
               EXEC rdt.rdtSetFocusField @n_Mobile, 6    
               GOTO RollBackTran    
            END    
            --SET @c_LabelNo = @c_TrackNo
         END
         ELSE
         BEGIN
         -- (james02)
         -- If it is move orders then can apply customize label no logic, 
         -- for sales orders then use tracking no as label no
            SET @c_GenLabelNo_SP = rdt.RDTGetConfig( @n_Func, 'PackByTrackNoGenLabelNo_SP', @c_Storerkey) 
            IF @c_GenLabelNo_SP NOT IN ('', '0') AND 
               EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @c_GenLabelNo_SP AND type = 'P')
            BEGIN
               SET @n_ErrNo = 0
               SET @c_SQLStatement = 'EXEC rdt.' + RTRIM( @c_GenLabelNo_SP) +     
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, ' + 
                  ' @cTrackNo, @cSKU, @cLabelNo OUTPUT, @nCartonNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
               SET @c_SQLParms =    
                  '@nMobile                   INT,           ' +
                  '@nFunc                     INT,           ' +
                  '@cLangCode                 NVARCHAR( 3),  ' +
                  '@nStep                     INT,           ' +
                  '@nInputKey                 INT,           ' +
                  '@cStorerkey                NVARCHAR( 15), ' +
                  '@cOrderKey                 NVARCHAR( 10), ' +
                  '@cPickSlipNo               NVARCHAR( 10), ' +
                  '@cTrackNo                  NVARCHAR( 20), ' +
                  '@cSKU                      NVARCHAR( 20), ' +
                  '@cLabelNo                  NVARCHAR( 20) OUTPUT, ' +
                  '@nCartonNo                 INT           OUTPUT, ' +
                  '@nErrNo                    INT           OUTPUT, ' +
                  '@cErrMsg                   NVARCHAR( 20) OUTPUT  ' 
               
               EXEC sp_ExecuteSQL @c_SQLStatement, @c_SQLParms,     
                  @n_Mobile, @n_Func, @c_LangCode, @n_Step, @n_InputKey, @c_Storerkey, @c_OrderKey, @c_PickSlipNo, 
                  @c_TrackNo, @c_SKU, @c_LabelNo OUTPUT, @n_CartonNo OUTPUT, @n_ErrNo OUTPUT, @c_ErrMsg OUTPUT 

               IF @n_ErrNo <> 0
               BEGIN    
                  SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP')
                  EXEC rdt.rdtSetFocusField @n_Mobile, 6    
                  GOTO RollBackTran    
               END    
            END
            ELSE
            BEGIN
               -- Get new LabelNo    
               EXECUTE isp_GenUCCLabelNo    
                        @c_Storerkey,    
                        @c_LabelNo    OUTPUT,    
                        @b_Success     OUTPUT,    
                        @n_ErrNo       OUTPUT,    
                        @c_ErrMsg      OUTPUT    
    
               IF @b_Success <> 1    
               BEGIN    
                  SET @n_ErrNo = 57577    
                  SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'GET LABEL Fail'    
                  EXEC rdt.rdtSetFocusField @n_Mobile, 6    
                  GOTO RollBackTran    
               END    
            END
         END

         -- CartonNo = 0 & LabelLine = '0000', trigger will auto assign    
         INSERT INTO dbo.PackDetail    
            (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate, DropID, UPC, LOTTABLEVALUE)    
         VALUES    
            (@c_PickSlipNo, 0, @c_LabelNo, '00000', @c_Storerkey, @c_SKU, 1,    
            '', 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), @c_DropID, @c_Barcode, @c_Barcode)   

         IF @@ERROR <> 0    
         BEGIN    
            SET @n_ErrNo = 57578    
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'INSPKDET Failed'    
            EXEC rdt.rdtSetFocusField @n_Mobile, 6    
            GOTO RollBackTran    
         END    
      END    
      ELSE    
      BEGIN    
         SET @c_CurLabelNo = ''    
         SET @c_CurLabelLine = ''    
             
         SELECT TOP 1 @c_CurLabelNo = LabelNo FROM dbo.PackDetail WITH (NOLOCK)     
         WHERE StorerKey = @c_Storerkey    
         AND PickSlipNo = @c_PickSlipNo    
         AND CartonNo = @n_CartonNo    
 
         SELECT @c_CurLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)      
         FROM PACKDETAIL WITH (NOLOCK)      
         WHERE StorerKey = @c_Storerkey    
         AND PickSlipNo = @c_PickSlipNo    
         AND CartonNo = @n_CartonNo    
 
         -- need to use the existing labelno    
         INSERT INTO dbo.PackDetail    
            (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate, DropID, UPC, LOTTABLEVALUE)    
         VALUES    
            (@c_PickSlipNo, @n_CartonNo, @c_CurLabelNo, @c_CurLabelLine, @c_Storerkey, @c_SKU, 1,    
            '', 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), @c_DropID, @c_Barcode, @c_Barcode)    

         IF @@ERROR <> 0    
         BEGIN    
            SET @n_ErrNo = 57579    
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'INSPKDET Failed'    
            EXEC rdt.rdtSetFocusField @n_Mobile, 6    
            GOTO RollBackTran    
         END    
      END    
   END    

   IF @n_SwapLot = 0
   BEGIN
      DECLARE @c_PDBorrow_Key  NVARCHAR(10)
      DECLARE @c_PDBorrow_Line NVARCHAR(5)
      DECLARE @c_PDBorrow_LOT  NVARCHAR(10)
      DECLARE @c_PDBorrow_LOC  NVARCHAR(10)
      DECLARE @c_PDBorrow_ID   NVARCHAR(18)
      DECLARE @n_PDBorrow_QTY  INT
      DECLARE @c_PDOwn_Key     NVARCHAR(10)
      DECLARE @c_PDOwn_LOT     NVARCHAR(10)
      DECLARE @n_PDOwn_QTY     INT
      DECLARE @n_PDOwn_MoveQTY INT

      SET @c_PDOwn_Key = ''
      SET @c_PDBorrow_Key = ''

      -- Get carton info
      SELECT TOP 1 
         @c_LabelNo = LabelNo 
      FROM dbo.PackDetail WITH (NOLOCK)    
      WHERE StorerKey = @c_Storerkey    
         AND PickSlipNo = @c_PickSlipNo    
         AND CartonNo = @n_CartonNo    
         AND SKU = @c_SKU
         AND UPC = @c_Barcode

      -- Find own/open PickDetail to offset
      SET @c_PDOwn_Key = ''
      SELECT TOP 1 
         @c_PDOwn_Key = PickDetailKey
      FROM dbo.PickDetail PD WITH (NOLOCK) 
         JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
      WHERE PD.StorerKey = @c_Storerkey
         AND PD.OrderKey = @c_OrderKey
         AND PD.SKU = @c_SKU
         AND PD.QTY > 0
         AND PD.Status < '9'
         AND (PD.DropID = @c_LabelNo OR PD.DropID = '') -- own carton or no carton
         AND PD.QTY > PD.QTYMoved   -- with balance
         AND LA.Lottable02 = @c_Lottable02
      
      -- Found own/open PickDetail
      IF @c_PDOwn_Key <> ''
      BEGIN
         -- Reduce other PickDetail
			UPDATE PickDetail SET
				QTYMoved = QTYMoved + 1, 
			   DropID = CASE WHEN DropID = '' THEN @c_LabelNo ELSE DropID END,
				EditWho = SUSER_SNAME(), 
				EditDate = GETDATE(), 
				TrafficCop = NULL
			WHERE PickDetailKey = @c_PDOwn_Key
         IF @@ERROR <> 0
         BEGIN
            SET @n_ErrNo = 57581
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') -- UPD PKDtl Fail
            GOTO RollBackTran
         END
         GOTO Quit
		END
         
      -- Find other PickDetail to borrow
      SET @c_PDBorrow_Key = ''
      SELECT TOP 1 
         @c_PDBorrow_Key = PickDetailKey, 
         @c_PDBorrow_Line = OrderLineNumber, 
         @c_PDBorrow_LOT = PD.LOT, 
         @c_PDBorrow_LOC = PD.LOC, 
         @c_PDBorrow_ID = PD.ID, 
         @n_PDBorrow_QTY = QTY
      FROM dbo.PickDetail PD WITH (NOLOCK) 
         JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
      WHERE PD.StorerKey = @c_Storerkey
         AND PD.OrderKey = @c_OrderKey
         AND PD.SKU = @c_SKU
         AND PD.QTY > 0
         AND PD.Status < '9'
         AND PD.DropID <> @c_LabelNo -- other carton
         AND PD.QTY > PD.QTYMoved    -- with balance
         AND LA.Lottable02 = @c_Lottable02

      -- Found other PickDetail to borrow
      IF @c_PDBorrow_Key <> ''
      BEGIN
         -- Find own PickDetail to topup (avoid split line, 1 QTY 1 line), but must be same line, LOT, LOC, ID
         SET @c_PDOwn_Key = ''
         SELECT TOP 1 
            @c_PDOwn_Key = PickDetailKey
         FROM dbo.PickDetail PD WITH (NOLOCK) 
            JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
         WHERE PD.StorerKey = @c_Storerkey
            AND PD.OrderKey = @c_OrderKey
            AND PD.SKU = @c_SKU
            AND PD.QTY > 0
            AND PD.Status < '9'
            AND PD.DropID = @c_LabelNo -- own carton or no carton
            AND PD.OrderLineNumber = @c_PDBorrow_Line
            AND PD.LOT = @c_PDBorrow_LOT
            AND PD.LOC = @c_PDBorrow_LOC
            AND PD.ID = @c_PDBorrow_ID
         
         -- Top up
         IF @c_PDOwn_Key <> ''
         BEGIN
            -- Reduce other
            UPDATE PickDetail SET
               QTY = QTY - 1, 
               EditDate = GETDATE(),
               EditWho  = SUSER_SNAME(),
               Trafficcop = NULL
            WHERE PickDetailKey = @c_PDBorrow_Key
            IF @@ERROR <> 0
            BEGIN
               SET @n_ErrNo = 57582
               SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') -- UPD PKDtl Fail
               GOTO RollBackTran
            END
                        
            -- Increase own
            UPDATE PickDetail SET
               QTY = QTY + 1, 
               QTYMoved = QTYMoved + 1, 
               EditDate = GETDATE(),
               EditWho  = SUSER_SNAME(),
               Trafficcop = NULL
            WHERE PickDetailKey = @c_PDOwn_Key
            IF @@ERROR <> 0
            BEGIN
               SET @n_ErrNo = 57583
               SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') -- UPD PKDtl Fail
               GOTO RollBackTran
            END
         END
         
         -- Split line
         ELSE 
         BEGIN         
            -- Get new PickDetailkey
            DECLARE @cNewPickDetailKey NVARCHAR( 10)
            EXECUTE dbo.nspg_GetKey
               'PICKDETAILKEY',
               10 ,
               @cNewPickDetailKey OUTPUT,
               @b_Success         OUTPUT,
               @n_ErrNo           OUTPUT,
               @c_ErrMsg          OUTPUT
            IF @b_Success <> 1
            BEGIN
               SET @n_ErrNo = 57584
               SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') -- GetKey Fail
               GOTO RollBackTran
            END

            -- Create a new PickDetail
            INSERT INTO dbo.PickDetail (
               CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM,
               UOMQTY, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType,
               ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
               EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,
               PickDetailKey,
               Status, 
               DropID, 
               QTY,
               QTYMoved, 
               TrafficCop,
               OptimizeCop)
            SELECT
               CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM,
               UOMQTY, LOC, ID, PackKey, UpdateSource, CartonGroup,
               CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
               EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,
               @cNewPickDetailKey,
               Status, 
               @c_LabelNo, -- DropID
               1,    -- QTY
               1,    -- QTYMoved
               NULL, -- TrafficCop
               '1'   -- OptimizeCop
            FROM dbo.PickDetail WITH (NOLOCK)
   			WHERE PickDetailKey = @c_PDBorrow_Key
            IF @@ERROR <> 0
            BEGIN
   			 SET @n_ErrNo = 57585
               SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') -- INS PKDtl Fail
               GOTO RollBackTran
            END

            -- Split RefKeyLookup
            IF EXISTS( SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @c_PDBorrow_Key)
            BEGIN
               -- Insert into
               INSERT INTO dbo.RefKeyLookup (PickDetailkey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey)
               SELECT @cNewPickDetailKey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey
               FROM RefKeyLookup WITH (NOLOCK) 
               WHERE PickDetailKey = @c_PDBorrow_Key
               IF @@ERROR <> 0
               BEGIN
                  SET @n_ErrNo = 57586
                  SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') -- INS RefKeyFail
                  GOTO RollBackTran
               END
            END

            -- Change borrow PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               QTY = QTY - 1,
               EditDate = GETDATE(),
               EditWho  = SUSER_SNAME(),
               Trafficcop = NULL
            WHERE PickDetailKey = @c_PDBorrow_Key
            IF @@ERROR <> 0
            BEGIN
               SET @n_ErrNo = 57587
               SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') -- UPD PKDtl Fail
               GOTO RollBackTran
            END
         END
            
         -- Delete PickDetail with QTY=0
         IF @n_PDBorrow_QTY = 1
         BEGIN
            DELETE PickDetail WHERE PickDetailKey = @c_PDBorrow_Key
            IF @@ERROR <> 0
            BEGIN
               SET @n_ErrNo = 57588
               SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') -- UPD PKDtl Fail
               GOTO RollBackTran
            END
         END
      END
      ELSE
      BEGIN    
         SET @n_ErrNo = 57589
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') -- Offset error 
         GOTO RollBackTran    
      END 
   END

   COMMIT TRAN rdtHnMSwapLot02
   GOTO Quit
   
   RollBackTran:  
      ROLLBACK TRAN rdtHnMSwapLot02  

   Quit:  
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
         COMMIT TRAN  

   Quit_WithoutTran:
   IF rdt.RDTGetConfig( @n_Func, 'ShowErrMsgInNewScn', @c_Storerkey) = '1'
   BEGIN
      IF @n_ErrNo > 0 AND @n_ErrNo <> 1  -- Not from prev msgqueue
      BEGIN
         SET @c_ErrMsg1 = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP')
         EXEC rdt.rdtInsertMsgQueue @n_Mobile, @n_MsgQErrNo OUTPUT, @n_MsgQErrMsg OUTPUT, @c_ErrMsg1
         IF @n_MsgQErrNo = 1
            SET @c_ErrMsg1 = ''
      END
   END
END -- End Procedure

GO