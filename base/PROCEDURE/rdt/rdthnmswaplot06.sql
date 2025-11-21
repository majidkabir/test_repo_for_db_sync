SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtHnMSwapLot06                                     */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: HMCOS JP swap lot logic                                     */
/*                                                                      */
/* Called from: rdtfnc_PackByTrackNo                                    */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 15-Nov-2019 1.0  James       WMS-11146. Created                      */
/* 16-Apr-2021 1.1  James       WMS-16024 Standarized use of TrackingNo */
/*                              (james01)                               */
/* 15-09-2022  1.2  James       WMS-20788 Use running no as labelno     */
/*                              Add scanned barcode to                  */
/*                              PackDetail.LottableValue (james02)      */
/* 02-12-2022  1.3  James       WMS-20788 Add move orders type generate */
/*                              labelnologic (james03)                  */
/************************************************************************/

CREATE   PROC [RDT].[rdtHnMSwapLot06] (
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
           @c_GenLabelNo_SP         NVARCHAR( 20),
           @nFragileChk             INT,
           @cOrderGroup             NVARCHAR( 20)

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
      SET @n_ErrNo = 146101    
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'Invalid Order'    
      GOTO Quit_WithoutTran
   END

   IF ISNULL( @c_SKU, '') = '' 
   BEGIN
      SET @n_ErrNo = 146102    
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'Invalid SKU'    
      GOTO Quit_WithoutTran
   END

   IF ISNULL( @c_Lottable02, '') = '' 
   BEGIN
      SET @n_ErrNo = 146103    
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'Invalid LOT02'    
      GOTO Quit_WithoutTran
   END

   IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK) 
                   WHERE StorerKey = @c_Storerkey
                   AND   OrderKey = @c_OrderKey
                   AND   SKU = @c_SKU
                   AND   [Status] < '9')
   BEGIN
      SET @n_ErrNo = 146104    
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'SKU NOT IN ORD'    
      GOTO Quit_WithoutTran
   END

   SELECT @c_UserName = UserName FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE Mobile = @n_Mobile

   SELECT @c_LoadKey = ISNULL(RTRIM(LoadKey),'')    
         , @c_Route = ISNULL(RTRIM(Route),'')    
         , @c_ConsigneeKey = ISNULL(RTRIM(ConsigneeKey),'')    
         , @cOrderGroup = OrderGroup
   FROM dbo.Orders WITH (NOLOCK)    
   WHERE Orderkey = @c_Orderkey    

   -- If it is not Sales type order then no need swap lot. Check validity of 2D barcode
   IF EXISTS ( SELECT 1 FROM dbo.CODELKUP C WITH (NOLOCK) 
               JOIN dbo.Orders O WITH (NOLOCK) ON (C.Code = O.OrderGroup AND C.StorerKey = O.StorerKey)
               WHERE C.ListName = 'HMCOSORD'
               AND   C.Long = 'M'
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
         SET @n_ErrNo = 146105    
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'Invalid Label'    
         GOTO Quit_WithoutTran
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
         SET @n_ErrNo = 146106    
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'COD Orders'    
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
      SET @n_ErrNo = 146107
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'SKU OVERPACKED'
      GOTO Quit_WithoutTran
   END

   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  -- Begin our own transaction  
   SAVE TRAN rdtHnMSwapLot06 -- For rollback or commit only our own transaction  

   IF @n_SwapLot = 0
   BEGIN
      UPDATE TOP (1) dbo.PickDetail SET 
         QTYMoved = QTYMoved + 1
      FROM dbo.PickDetail PD WITH (NOLOCK) 
         JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
      WHERE PD.StorerKey = @c_Storerkey
         AND PD.OrderKey = @c_OrderKey
         AND PD.SKU = @c_SKU
         AND PD.Status < '9'
         AND PD.QtyMoved < PD.QTY
         AND LA.Lottable02 = @c_Lottable02
      IF @@ERROR <> 0    
      BEGIN    
         SET @n_ErrNo = 146108    
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') ----'UPDPKDET Fail' 
         EXEC rdt.rdtSetFocusField @n_Mobile, 6
         GOTO RollBackTran    
      END 
   END

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
         SET @n_ErrNo = 146109
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
               SET @n_ErrNo = 146110    
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
               SET @n_ErrNo = 146111 
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
                  SET @n_ErrNo = 146112 
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
               SET @n_ErrNo = 146113 
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
                     SET @n_ErrNo = 146114
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
                     SET @n_ErrNo = 146115
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
                        SET @n_ErrNo = 146116
                        SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'SWAP LOT FAIL'
                        set @n_Continue = 3
                     END
                     BREAK
                  END
                  ELSE
                  BEGIN
                     SET @n_ErrNo = 146117
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
         SET @n_ErrNo = 146118    
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
         SET @n_ErrNo = 146119    
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'InsLog Failed'    
         EXEC rdt.rdtSetFocusField @n_Mobile, 6    
         GOTO RollBackTran    
      END    
   END    

   -- Create PackHeader if not yet created    
   IF NOT EXISTS (SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo)    
   BEGIN    
      INSERT INTO dbo.PACKHEADER    
      (PickSlipNo, StorerKey, OrderKey, LoadKey, Route, ConsigneeKey, OrderRefNo, TtlCnts, [STATUS])     
      VALUES    
      (@c_PickSlipNo, @c_Storerkey, @c_Orderkey, @c_LoadKey, @c_Route, @c_ConsigneeKey, '', 0, '0')     
          
       IF @@ERROR <> 0    
       BEGIN    
         SET @n_ErrNo = 146120    
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'InsPKHDR Failed'    
         EXEC rdt.rdtSetFocusField @n_Mobile, 6    
         GOTO RollBackTran    
      END    
   END    

   -- Use running no as temp label no. Interface will then update to correct labelno (james02)

   -- If customer order (only customer order can swap lot)
   IF @n_SwapLot = 1
   BEGIN
      -- Get tracking no. Customer order can have > 1 carton
      -- If 1st carton then get the tracking no from orders.userdefine04
      IF @n_CartonNo = 1
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
            SET @n_ErrNo = 146126    
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'GET LABEL Fail'    
            EXEC rdt.rdtSetFocusField @n_Mobile, 6    
            GOTO RollBackTran    
         END    

         SET @c_TrackNo = @c_LabelNo
         /*
         --SELECT @c_TrackNo = UserDefine04
         SELECT @c_TrackNo = TrackingNo   -- (james01)
         FROM dbo.Orders WITH (NOLOCK) 
         WHERE StorerKey = @c_StorerKey
         AND   OrderKey = @c_OrderKey

         IF ISNULL( @c_TrackNo, '') = ''
         BEGIN    
            SET @n_ErrNo = 146121    
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'NO TRACKING #'    
            EXEC rdt.rdtSetFocusField @n_Mobile, 6    
            GOTO RollBackTran    
         END    */
      END
      ELSE
      BEGIN
         -- Check if same carton exists before. Diff sku can scan into same carton    
         IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)    
                    WHERE StorerKey = @c_Storerkey    
                    AND PickSlipNo = @c_PickSlipNo    
                    AND CartonNo = @n_CartonNo)    
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
               SET @n_ErrNo = 146126    
               SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'GET LABEL Fail'    
               EXEC rdt.rdtSetFocusField @n_Mobile, 6    
               GOTO RollBackTran    
            END    

            SET @c_TrackNo = @c_LabelNo

         /*	
           /** get new available pre-paid tracking number **/
            SELECT @c_CarrierName = Code, 
                   @c_KeyName = UDF05
            FROM dbo.Codelkup WITH (NOLOCK)
            WHERE Listname = 'COSCourier' 
            AND   Long = 'NORMAL' 
            AND   StorerKey = @c_Storerkey

            SELECT @c_TrackNo = MIN( TrackingNo)
            FROM dbo.CartonTrack WITH (NOLOCK)
            WHERE CarrierName = @c_CarrierName 
            AND   Keyname = @c_KeyName 
            AND   ISNULL( CarrierRef2, '') = ''

            IF ISNULL( @c_TrackNo, '') = ''
            BEGIN    
               SET @n_ErrNo = 146122    
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
               SET @n_ErrNo = 146123    
               SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'ASSIGN TRACK# FAIL'    
               EXEC rdt.rdtSetFocusField @n_Mobile, 6    
               GOTO RollBackTran    
            END */
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
            CaseID = @c_TempCaseID, --@c_TrackNo, 
            TrafficCop = NULL
         WHERE StorerKey = @c_StorerKey
         AND   OrderKey = @c_OrderKey
         AND   QtyMoved = 1
         AND   CaseID = RTRIM( @c_PickSlipNo) + CAST( @n_CartonNo AS NVARCHAR( 2))

         IF @@ERROR <> 0
         BEGIN    
            SET @n_ErrNo = 146124    
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'ASSIGN TRACK# FAIL'    
            EXEC rdt.rdtSetFocusField @n_Mobile, 6    
            GOTO RollBackTran    
         END 
      END
   END

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
         SET @n_ErrNo = 146125    
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
      	IF @cOrderGroup <> 'MOVE'
      	   SET @c_LabelNo = @c_TrackNo

         ---- Set label no = tracking no (Only for customer orders)
         --IF @n_SwapLot = 1
         --   SET @c_LabelNo = @c_TrackNo
         ELSE
         BEGIN
         -- (james02)/(james03)
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
                  SET @n_ErrNo = 146126    
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
            SET @n_ErrNo = 146127    
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
            SET @n_ErrNo = 146128    
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'INSPKDET Failed'    
            EXEC rdt.rdtSetFocusField @n_Mobile, 6    
            GOTO RollBackTran    
         END    
      END    
   END    

             
   COMMIT TRAN rdtHnMSwapLot06
   GOTO Quit
   
   RollBackTran:  
      ROLLBACK TRAN rdtHnMSwapLot06  

   Fail:  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
         COMMIT TRAN  

   Quit_WithoutTran:

END -- End Procedure

GO