SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdtHnMSwapLot05                                     */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: H&M swap lot                                                */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 16-11-2018  1.0  James       Temp fix. Packing function. No swap lot */
/************************************************************************/

CREATE PROC [RDT].[rdtHnMSwapLot05] (
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
           @n_err                   INT, 
           @c_LangCode              NVARCHAR( 3), 
           @c_PickDetailKey         NVARCHAR( 10), 
           @nTranCount              INT, 
           @nLLI_Qty                INT, 
           @nPD_Qty                 INT, 
           @n_Continue              INT, 
           @n_SwapLot               INT 

           
   SET @n_ErrNo = 0
   SET @n_SwapLot = 1

   IF ISNULL( @c_OrderKey, '') = ''
   BEGIN
      SET @n_ErrNo = 87051    
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'Invalid Order'    
      GOTO Quit_WithoutTran
   END

   IF ISNULL( @c_SKU, '') = '' 
   BEGIN
      SET @n_ErrNo = 87052    
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'Invalid SKU'    
      GOTO Quit_WithoutTran
   END

   IF ISNULL( @c_Lottable02, '') = '' 
   BEGIN
      SET @n_ErrNo = 87053    
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'Invalid LOT02'    
      GOTO Quit_WithoutTran
   END

   IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK) 
                   WHERE StorerKey = @c_Storerkey
                   AND   OrderKey = @c_OrderKey
                   AND   SKU = @c_SKU
                   AND   [Status] < '9')
   BEGIN
      SET @n_ErrNo = 87071    
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
         SET @n_ErrNo = 87054    
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'Invalid Label'    
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
      SET @n_ErrNo = 87055
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'SKU OVERPACKED'
      GOTO Quit_WithoutTran
   END

   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  -- Begin our own transaction  
   SAVE TRAN rdtHnMSwapLot05 -- For rollback or commit only our own transaction  
   /*
   IF @n_SwapLot = 0
   BEGIN
      UPDATE TOP (1) dbo.PickDetail SET 
         EditDate = GETDATE(),    
         EditWho = 'rdt.' + sUser_sName(),   
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
         SET @n_ErrNo = 87056    
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') ----'UPDPKDET Fail' 
         EXEC rdt.rdtSetFocusField @n_Mobile, 6
         GOTO RollBackTran    
      END 
   END

   IF @n_SwapLot = 1
   BEGIN
      /*
      SELECT TOP 1 @c_Lottable03 = LA.Lottable03
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
      JOIN dbo.LOC LOC WITH (NOLOCK) ON LLI.LOC = LOC.LOC 
      JOIN dbo.LotAttribute LA WITH (NOLOCK) ON LLI.LOT = LA.LOT 
      WHERE LLI.Storerkey = @c_StorerKey 
      AND   LLI.SKU = @c_SKU 
      AND   SUBSTRING(LA.Lottable02, 5, 2)+ RTRIM(LLI.SKU) + SUBSTRING(LA.Lottable02, 1 , 12) + SUBSTRING(LA.Lottable02, 14, 2) = @c_Barcode
      AND   LLI.Qty > 0
      */
      
      -- For H&M, 1 orders only have 1 lottable03. STD for normal cust order. BLO for move order
      SELECT TOP 1 @c_Lottable03 = Lottable03 
      FROM dbo.OrderDetail WITH (NOLOCK) 
      WHERE StorerKey = @c_StorerKey
      AND   OrderKey = @c_Orderkey
      AND   SKU = @c_SKU
      
   /*
      SELECT @nLLI_Qty = ISNULL( SUM( Qty), 0)  -- All qty can be swapped
      FROM dbo.LOTXLOCXID LLI WITH (NOLOCK) 
      JOIN dbo.LotAttribute LA WITH (NOLOCK) ON LLI.LOT = LA.LOT 
      WHERE LLI.Storerkey = @c_StorerKey    
      AND   LLI.SKU = @c_SKU
      AND   LLI.LOC = @c_LOC
      AND   LA.Lottable02 = @c_Lottable02

      SELECT @nPD_Qty = ISNULL( SUM( QTY), 0)
      FROM dbo.PickDetail PD WITH (NOLOCK) 
      JOIN dbo.LotAttribute LA WITH (NOLOCK) ON PD.LOT = LA.LOT
      WHERE PD.Storerkey = @c_StorerKey    
      AND   PD.Status = '0'
      AND   PD.SKU = @c_SKU
      AND   PD.LOC = @c_LOC
      AND   PD.QtyMoved = 1
      AND   LA.Lottable02 = @c_Lottable02

      IF @nPD_Qty + 1 > @nLLI_Qty 
      BEGIN
         SET @n_ErrNo = 87056
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'SKU OVERPACKED'
         GOTO Quit_WithoutTran
      END
   */
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
         SET @n_ErrNo = 87072
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
               EditDate = GETDATE(),    
               EditWho = 'rdt.' + sUser_sName(),    
               QtyMoved = 1, 
               Trafficcop = NULL
            WHERE PickDetailKey = @c_PickDetailKey
            
            IF @@ERROR <> 0    
            BEGIN    
               SET @n_ErrNo = 87066    
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
               SET @n_ErrNo = 87057 
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
                  SET @n_ErrNo = 87073 
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
               SET @n_ErrNo = 87058 
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
                     EditDate = GETDATE(),    
                     EditWho = 'rdt.' + sUser_sName(),    
                     Lot = @c_TargetLot, 
                     ID = @c_TargetID, 
                     QtyMoved = 1, 
                     Trafficcop = NULL
                  WHERE PickDetailKey = @c_PickDetailKey

                  IF @@ERROR <> 0
                  BEGIN
                     SET @n_ErrNo = 87059
                     SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'SWAP LOT FAIL'
                     SET @n_Continue = 3
                     BREAK
                  END
                     
                  -- Swap target lot
                  UPDATE PickDetail WITH (ROWLOCK) SET 
                     EditDate = GETDATE(),    
                     EditWho = 'rdt.' + sUser_sName(),    
                     Lot = @c_Lot, 
                     ID = @c_ID, 
                     Trafficcop = NULL
                  WHERE PickDetailKey = @c_TargetPickDetailKey

                  IF @@ERROR <> 0
                  BEGIN
                     SET @n_ErrNo = 87060
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
                        EditDate = GETDATE(),    
                        EditWho = 'rdt.' + sUser_sName(),    
                        Lot = @c_NewLOT, 
                        ID = @c_NewID, 
                        QtyMoved = 1 
                     WHERE PickDetailKey = @c_PickDetailKey

                     IF @@ERROR <> 0
                     BEGIN
                        SET @n_ErrNo = 87061
                        SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'SWAP LOT FAIL'
                        set @n_Continue = 3
                     END
                     BREAK
                  END
                  ELSE
                  BEGIN
                     SET @n_ErrNo = 87062
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
   */
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
         SET @n_ErrNo = 87063    
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
         SET @n_ErrNo = 87064    
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
         SET @n_ErrNo = 87065    
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'InsPKHDR Failed'    
         EXEC rdt.rdtSetFocusField @n_Mobile, 6    
         GOTO RollBackTran    
      END    
   END    

/*
   -- (james07)
   SELECT TOP 1 @c_PickDetailKey = PID.PickDetailKey 
   FROM dbo.PickDetail PID WITH (NOLOCK) 
   JOIN dbo.LotAttribute LA WITH (NOLOCK) ON PID.LOT = LA.LOT
   WHERE PID.Orderkey = @c_Orderkey    
   AND   PID.Storerkey = @c_Storerkey    
   AND   PID.Status < '9'
   AND   PID.SKU = @c_SKU
   AND   LA.Lottable02 = @c_Lottable02
   AND   QtyMoved = 0

   UPDATE PickDetail WITH (ROWLOCK) SET 
      QtyMoved = 1, Trafficcop = NULL
   WHERE PickDetailKey = @c_PickDetailKey
   
   IF @@ERROR <> 0    
   BEGIN    
      SET @n_ErrNo = 87066    
      SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'UPDPKDET Failed'    
      EXEC rdt.rdtSetFocusField @n_Mobile, 6    
      GOTO RollBackTran    
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
         SET @n_ErrNo = 87067    
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
         -- Get new LabelNo    
         EXECUTE isp_GenUCCLabelNo    
                  @c_Storerkey,    
                  @c_LabelNo    OUTPUT,    
                  @b_Success     OUTPUT,    
                  @n_ErrNo       OUTPUT,    
                  @c_ErrMsg      OUTPUT    
 
         IF @b_Success <> 1    
         BEGIN    
            SET @n_ErrNo = 87068    
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'GET LABEL Fail'    
            EXEC rdt.rdtSetFocusField @n_Mobile, 6    
            GOTO RollBackTran    
         END    

         -- CartonNo = 0 & LabelLine = '0000', trigger will auto assign    
         INSERT INTO dbo.PackDetail    
            (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate, DropID, UPC)    
         VALUES    
            (@c_PickSlipNo, 0, @c_LabelNo, '00000', @c_Storerkey, @c_SKU, 1,    
            '', 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), '', @c_Barcode)   

         IF @@ERROR <> 0    
         BEGIN    
            SET @n_ErrNo = 87069    
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
            (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate, DropID, UPC)    
         VALUES    
            (@c_PickSlipNo, @n_CartonNo, @c_CurLabelNo, @c_CurLabelLine, @c_Storerkey, @c_SKU, 1,    
            '', 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), '', @c_Barcode)    

         IF @@ERROR <> 0    
         BEGIN    
            SET @n_ErrNo = 87070    
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'INSPKDET Failed'    
            EXEC rdt.rdtSetFocusField @n_Mobile, 6    
            GOTO RollBackTran    
         END    
      END    
   END    
   
   COMMIT TRAN rdtHnMSwapLot05
   GOTO Quit
   
   RollBackTran:  
      ROLLBACK TRAN rdtHnMSwapLot05  

   Fail:  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
         COMMIT TRAN  

   Quit_WithoutTran:

END -- End Procedure

GO