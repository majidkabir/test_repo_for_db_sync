SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdtHnMSwapLot01                                     */
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
/* 27-02-2014  1.0  James       SOS300492 Created                       */
/* 09-07-2014  1.1  James       Bug fix (james01)                       */
/* 30-07-2014  1.2  James       Add 2D barcode into packdetail.upc      */
/* 20-08-2014  1.3  James       Get Lottable03 from OrderDetail         */
/* 27-08-2014  1.4  Ung         Fix move order should pick exact lot    */
/* 30-07-2018  1.5  James       Perf tuning (james02)                   */
/* 26-12-2018  1.6  James       WMS7147-Add printing (sales order only) */
/* 13-05-2019  1.7  James       WMS9005-Add config to print Delnotes    */
/* 30-09-2020  1.8  James       WMS-15326 Add Stdeventlog (james03)     */
/* 18-02-2021  1.9  James       WMS-16145 Add stamp pickdetail.dropid   */
/*                              for move orders only (james04)          */
/* 16-04-2021  2.0  James       WMS-16024 Standarized use of TrackingNo */
/*                              (james05)                               */
/************************************************************************/

CREATE PROC [RDT].[rdtHnMSwapLot01] (
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
           @c_SQLStatement          NVARCHAR(2000),
           @c_SQLParms              NVARCHAR(2000),
           @c_GenLabelNo_SP         NVARCHAR( 20),
           @nTranCount              INT, 
           @nLLI_Qty                INT, 
           @n_Continue              INT, 
           @n_SwapLot               INT, 
           @n_Func                  INT, 
           @n_Step                  INT,
           @n_InputKey              INT,
           @c_ShipperKey            NVARCHAR( 15),
           @c_DocType               NVARCHAR( 10),
           @c_Facility              NVARCHAR( 5),
           @c_LabelPrinter          NVARCHAR( 10),
           @c_PaperPrinter          NVARCHAR( 10),
           @c_DelNotes              NVARCHAR( 10),
           @c_DropID                NVARCHAR( 20),
           @c_NewDropID             NVARCHAR( 20),
           @n_Pack_QTY              INT,
           @n_NewCarton             INT,
           @n_PD_QTY                INT           

           
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

   SELECT @c_UserName = UserName, 
          @n_Func = Func,
          @n_Step = Step, 
          @n_InputKey = InputKey,
          @c_LabelPrinter = Printer,
          @c_PaperPrinter = Printer_Paper,
          @c_Facility = Facility
   FROM RDT.RDTMOBREC WITH (NOLOCK) 
   WHERE Mobile = @n_Mobile

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
   SAVE TRAN rdtHnMSwapLot01 -- For rollback or commit only our own transaction  

   IF @n_SwapLot = 0
   BEGIN
      UPDATE TOP (1) dbo.PickDetail SET 
         EditDate = GETDATE(),    
         EditWho = 'rdt.' + sUser_sName(),   
         QTYMoved = CASE WHEN QTYMoved = 0 THEN 1 ELSE QTYMoved END
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
   /*
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

      SELECT TOP 1 @c_CurLabelNo = LabelNo 
      FROM dbo.PackDetail WITH (NOLOCK)     
      WHERE StorerKey = @c_Storerkey    
      AND PickSlipNo = @c_PickSlipNo    
      AND CartonNo = @n_CartonNo  
      ORDER BY 1
   END    
   ELSE     -- Insert new PackDetail    
   BEGIN    
      -- Check if same carton exists before. Diff sku can scan into same carton    
      IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)    
                 WHERE StorerKey = @c_Storerkey    
                 AND PickSlipNo = @c_PickSlipNo    
                 AND CartonNo = @n_CartonNo)    
      BEGIN    
         SET @c_GenLabelNo_SP = rdt.RDTGetConfig( @n_Func, 'PackByTrackNoGenLabelNo_SP', @c_Storerkey) 
         IF @c_GenLabelNo_SP NOT IN ('', '0') AND 
            EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @c_GenLabelNo_SP AND type = 'P')
         BEGIN
            SET @n_ErrNo = 0
            SET @c_SQLStatement = 'EXEC rdt.' + RTRIM( @c_GenLabelNo_SP) +     
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cOrderKey, @cPickSlipNo, ' + 
               ' @cTrackNo, @cSKU, @cLabelNo OUTPUT, @nCartonNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
            SET @c_SQLParms =    
               '@nMobile                   INT,           ' +
               '@nFunc                     INT,           ' +
               '@cLangCode                 NVARCHAR( 3),  ' +
               '@nStep                     INT,           ' +
               '@nInputKey                 INT,           ' +
               '@cStorerKey                NVARCHAR( 15), ' +
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
         ELSE  -- If customer/sales order then use regular method to generate LabelNo
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
         ELSE
            SELECT @n_NewCarton = CartonNo 
            FROM dbo.PackDetail WITH (NOLOCK) 
            WHERE PickSlipNo = @c_PickSlipNo
            AND   LabelNo = @c_LabelNo
            AND   StorerKey = @c_StorerKey
      END    
      ELSE    
      BEGIN    
         SET @c_CurLabelNo = ''    
         SET @c_CurLabelLine = ''    
             
         SELECT TOP 1 @c_CurLabelNo = LabelNo 
         FROM dbo.PackDetail WITH (NOLOCK)     
         WHERE StorerKey = @c_Storerkey    
         AND PickSlipNo = @c_PickSlipNo    
         AND CartonNo = @n_CartonNo    
         ORDER BY 1
         
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

   -- Printing start here (only for sales orders)
   IF @n_SwapLot = 1
   BEGIN
      -- 1 orders 1 tracking no
      -- discrete pickslip, 1 ordes 1 pickslipno
      SET @n_ExpectedQty = 0
      SELECT @n_ExpectedQty = ISNULL(SUM(Qty), 0) FROM PickDetail WITH (NOLOCK)
      WHERE Orderkey = @c_OrderKey
         AND Storerkey = @c_Storerkey
         AND Status < '9'

      SET @n_PackedQty = 0
      SELECT @n_PackedQty = ISNULL(SUM(Qty), 0) FROM dbo.PackDetail WITH (NOLOCK)
      WHERE PickSlipNo = @c_PickSlipNo
         AND Storerkey = @c_Storerkey

      -- all SKU and qty has been packed, Update the carton barcode to the PackDetail.UPC for each carton
      IF @n_ExpectedQty = @n_PackedQty
      BEGIN
         SET @c_DelNotes = rdt.RDTGetConfig( @n_Func, 'DelNotes', @c_Storerkey)
         IF @c_DelNotes = '0'
            SET @c_DelNotes = ''   

         SELECT @c_LoadKey = ISNULL(RTRIM(LoadKey), ''),
                @c_ShipperKey = ISNULL(RTRIM(ShipperKey), ''),
                @c_DocType = DocType
         FROM dbo.Orders WITH (NOLOCK)
         WHERE Storerkey = @c_Storerkey
         AND   Orderkey = @c_Orderkey

         IF @c_DocType = 'E' AND @c_DelNotes <> ''
         BEGIN
            DECLARE @tDELNOTES AS VariableTable
            INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@c_OrderKey',    @c_OrderKey)
            INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@cLoadKey',     '')
            INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@cType',        '')

            -- Print label
            EXEC RDT.rdt_Print @n_Mobile, @n_Func, @c_LangCode, @n_Step, @n_InputKey, @c_Facility, @c_Storerkey, '', @c_PaperPrinter, 
               @c_DelNotes, -- Report type
               @tDELNOTES, -- Report params
               'rdtHnMSwapLot01', 
               @n_ErrNo  OUTPUT,
               @c_ErrMsg OUTPUT 
         END
      END
   END/*
   ELSE
   BEGIN
      SET @n_Pack_QTY = 1

      IF @n_NewCarton > 0
         SET @c_NewDropID = @c_LabelNo
      ELSE
         SET @c_NewDropID = @c_CurLabelNo
         
      -- Stamp pickdetail.caseid (to know which case in which pickdetail line)
      DECLARE @cur_UpdPickDtl CURSOR
      SET @cur_UpdPickDtl = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PickDetailKey, QTY, DropID
      FROM dbo.PickDetail WITH (NOLOCK)
      WHERE OrderKey  = @c_OrderKey
      AND   StorerKey  = @c_StorerKey
      AND   SKU = @c_SKU
      AND   Status < '9'
      ORDER BY PickDetailKey
      OPEN @cur_UpdPickDtl
      FETCH NEXT FROM @cur_UpdPickDtl INTO @c_PickDetailKey, @n_PD_QTY, @c_DropID
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Exact match
         IF @n_PD_QTY = @n_Pack_QTY AND @c_DropID = ''
         BEGIN
            -- Confirm PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               DropID = @c_NewDropID, 
               TrafficCop = NULL
            WHERE PickDetailKey = @c_PickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @n_ErrNo = 87074
               SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'Upd DropID Err'
               GOTO RollBackTran
            END

            SET @n_Pack_QTY = @n_Pack_QTY - @n_PD_QTY -- Reduce balance 
         END
         -- PickDetail have less
         ELSE IF @n_PD_QTY < @n_Pack_QTY AND @c_DropID = ''
         BEGIN
            -- Confirm PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               DropID = @c_NewDropID, 
               TrafficCop = NULL
            WHERE PickDetailKey = @c_PickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @n_ErrNo = 87075
               SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'Upd DropID Err'
               GOTO RollBackTran
            END

            SET @n_Pack_QTY = @n_Pack_QTY - @n_PD_QTY -- Reduce balance
         END
         -- PickDetail have more, need to split
         ELSE IF @n_PD_QTY > @n_Pack_QTY
         BEGIN
            IF NOT EXISTS ( SELECT 1 FROM dbo.PICKDETAIL WITH (NOLOCK) 
                            WHERE PickDetailKey = @c_PickDetailKey
                            AND   DropID = @c_NewDropID)
            BEGIN
               IF @c_DropID <> ''
               BEGIN
                  -- Get new PickDetailkey
                  DECLARE @cNewPickDetailKey NVARCHAR( 10)
                  EXECUTE dbo.nspg_GetKey
                     'PICKDETAILKEY',
                     10 ,
                     @cNewPickDetailKey OUTPUT,
                     @b_success         OUTPUT,
                     @n_err             OUTPUT,
                     @c_errmsg          OUTPUT

                  IF @b_success <> 1
                  BEGIN
                     SET @n_ErrNo = 87076
                     SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') -- 'Get PDKey Fail'
                     GOTO RollBackTran
                  END

                  -- Create a new PickDetail to hold the balance
                  INSERT INTO dbo.PICKDETAIL (
                     CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM, UOMQTY, QTYMoved,
                     Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,
                     DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, PickDetailKey,
                     QTY,
                     TrafficCop,
                     OptimizeCop)
                  SELECT
                     CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM, UOMQTY, 0,
                     Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,
                     DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, @cNewPickDetailKey,
                     @n_PD_QTY - @n_Pack_QTY, 
                     NULL, --TrafficCop,
                     '1'  --OptimizeCop
                  FROM dbo.PickDetail WITH (NOLOCK)
                  WHERE PickDetailKey = @c_PickDetailKey

                  IF @@ERROR <> 0
                  BEGIN
                     SET @n_ErrNo = 870747
                     SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'Ins PDtl Fail'
                     GOTO RollBackTran
                  END

                  UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                     Qty = @n_Pack_QTY,   -- deduct original qty
                     DropID = @c_NewDropID, 
                     TrafficCop = NULL
                  WHERE PickDetailKey = @c_PickDetailKey

                  IF @@ERROR <> 0
                  BEGIN
                     SET @n_ErrNo = 87078
                     SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'Upd DropID Err'
                     GOTO RollBackTran
                  END

                
               END
               ELSE
               BEGIN
                  UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                     DropID = @c_NewDropID, 
                     TrafficCop = NULL
                  WHERE PickDetailKey = @c_PickDetailKey

                  IF @@ERROR <> 0
                  BEGIN
                     SET @n_ErrNo = 87079
                     SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --'Upd DropID Err'
                     GOTO RollBackTran
                  END
               END

               SET @n_Pack_QTY = 0  -- Reduce balance  
            END
         END

         IF @n_Pack_QTY = 0 
            BREAK -- Exit

         FETCH NEXT FROM @cur_UpdPickDtl INTO @c_PickDetailKey, @n_PD_QTY, @c_DropID
      END
   END*/
   
   IF ISNULL( @c_TrackNo, '') = ''
      --SELECT @c_TrackNo = UserDefine04
      SELECT @c_TrackNo = TrackingNo   -- (james05)
      FROM dbo.ORDERS WITH (NOLOCK)
      WHERE OrderKey = @c_OrderKey
 
   -- EventLog -- (james03)   
   EXEC RDT.rdt_STD_EventLog    
      @cActionType = '8', -- Packing    
      @nMobileNo   = @n_Mobile,    
      @nFunctionID = @n_Func,    
      @cFacility   = @c_Facility,    
      @cStorerKey  = @c_Storerkey,      
      @cSKU        = @c_SKU,  
      @nQty        = 1,  -- Piece packing qty always 1
      @cTrackingNo = @c_TrackNo,
      @cPickSlipNo = @c_PickSlipNo    
                 
   COMMIT TRAN rdtHnMSwapLot01
   GOTO Quit
   
   RollBackTran:  
      ROLLBACK TRAN rdtHnMSwapLot01  

   Fail:  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
         COMMIT TRAN  

   Quit_WithoutTran:

END -- End Procedure

GO