SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_GetPickSlipCMC                                 */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4.2                                                       */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 24-Aug-2005  June          SOS39856 - break execution if error occur */
/* 10-Aug-2006  UngDH         SOS55253 - RefKeyLookup record missing    */
/*                            sometimes. Various fixes, clean up source */ 
/* 09-Nov-2006  Vicky         Fix pickslipno generation                 */
/* 15-Nov-2006  James         SOS62253 - add sorting by pickslipno      */
/* 15-Jul-2010  KHLim     Replace USER_NAME to sUSER_sName              */ 
/* 25-JAN-2017  JayLim        SQL2012 compatibility modification (Jay01)*/ 
/************************************************************************/

CREATE PROC [dbo].[nsp_GetPickSlipCMC] (@c_LoadKey NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE 
      @n_continue       INT,
      @c_errmsg         NVARCHAR( 255),
      @b_success        INT,
      @n_err            INT,
      @cCreatePickSlip  NVARCHAR( 1),
      @cPrintedFlag     NVARCHAR( 1),
      @cPickSlipNo      NVARCHAR( 10),
      @cStorerKey       NVARCHAR( 15),
      @cSKU             NVARCHAR( 20),
      @cBillToKey       NVARCHAR( 15)

   CREATE TABLE #TempPickDetail 
   (
      LoadKey           NVARCHAR( 10),
      BillToKey         NVARCHAR( 15),
      PickDetailKey     NVARCHAR( 18),
      ExternOrderKey    NVARCHAR( 10),
      OrderKey          NVARCHAR( 10),
      OrderLineNumber   NVARCHAR( 5),
      StorerKey         NVARCHAR( 15),
      SKU               NVARCHAR( 20),
      UOM               NVARCHAR( 10),
      QTY               INT,
      LOT               NVARCHAR( 10),
      LOC               NVARCHAR( 10),
      ID                NVARCHAR( 18),
      PackKey           NVARCHAR( 10),
      PickSlipNo        NVARCHAR( 10) NULL,
      PrintedFlag       NVARCHAR( 1),
      AlLOCDate         DATETIME,
      Mthtogo           INT NULL
   )

   -- Check if PickSlip created
   IF EXISTS( SELECT 1 FROM PickHeader (NOLOCK) WHERE ExternOrderKey = @c_LoadKey AND Zone = 'LB')
   BEGIN
      SET @cCreatePickSlip = 'N'
      SET @cPrintedFlag = 'Y'

      -- Stamp PickSlip as printed
      UPDATE PickHeader SET 
         PickType = '1', -- PrintedFlag
         TrafficCop = NULL
      WHERE ExternOrderKey = @c_LoadKey
         AND Zone = 'LB'
         AND PickType = '0'
   END
   ELSE
   BEGIN
      SET @cCreatePickSlip = 'Y'
      SET @cPrintedFlag = 'N'
   END

   INSERT INTO #TempPickDetail (LoadKey, BillToKey, PickDetailKey, ExternOrderKey, OrderKey, OrderLineNumber, 
      StorerKey, SKU, PackKey, UOM, QTY, LOT, LOC, ID, PickSlipNo, PrintedFlag, AlLOCDate)
   SELECT LPD.LoadKey, O.BillToKey, PD.PickDetailKey, O.ExternOrderKey, PD.OrderKey, PD.OrderLineNumber, 
      PD.StorerKey, PD.SKU, PD.PackKey, OD.UOM, PD.QTY, PD.LOT, PD.LOC, PD.ID, 
      PD.PickSlipNo, @cPrintedFlag, CONVERT(DATETIME, CONVERT(CHAR(11), PD.ADDDATE, 106))
--   INTO #TempPickDetail
   FROM LoadPlanDetail LPD (NOLOCK)
      INNER JOIN Orders O (NOLOCK) ON (LPD.OrderKey = O.OrderKey)
      INNER JOIN OrderDetail OD (NOLOCK) ON (O.OrderKey = OD.OrderKey)
      INNER JOIN PickDetail PD (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
   WHERE LPD.LoadKey = @c_LoadKey
      AND OD.LoadKey = @c_LoadKey
      AND PD.Status < '5'
   ORDER BY PD.PickDetailKey
   IF @@ERROR <> 0 GOTO Quit

   -- Create the PickSlips
   IF @cCreatePickSlip = 'Y'
   BEGIN
      DECLARE @nKeys INT
      SET @nKeys = 0
      
      -- Just for getting distinct count from @@ROWCOUNT, without actually sending back result to front end
      DECLARE @cDummy1 NVARCHAR( 1) 
      DECLARE @cDummy2 NVARCHAR( 1)

-- Commented by Vicky on 09-Nov-2006 - Fix pickslipno generating (Start)
      -- Calculate how many PickSlipNo required
--       SELECT DISTINCT 
--          @cDummy1 = LoadKey, 
--          @cDummy2 = BillToKey
--       FROM #TempPickDetail
--       WHERE BillToKey <> ''
--       SET @nKeys = @@ROWCOUNT
--       IF @nKeys = 0 GOTO Quit -- Just in case
-- 
	      -- Reserve the PickSlipNo range
-- 			SET @b_success = 1
-- 			EXECUTE nspg_GetKey
-- 	   		'PICKSLIP'
-- 	   		, 9
-- 	   		, @cPickSlipNo  OUTPUT
-- 	   		, @b_success    OUTPUT
-- 	   		, @n_err        OUTPUT
-- 	   		, @c_errmsg     OUTPUT
-- 	         , 0  -- Debug
-- 
-- 	      IF @b_success <> 1 GOTO Quit
-- 	      SET @cPickSlipNo = 'P' + @cPickSlipNo
-- Commented by Vicky on 09-Nov-2006 - Fix pickslipno generating (End)

      -- Get the PickSlip
      DECLARE cur_PickSlip CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT LoadKey, BillToKey
         FROM #TempPickDetail
         WHERE BillToKey <> ''
         ORDER BY LoadKey, BillToKey

      OPEN cur_PickSlip
      FETCH NEXT FROM cur_PickSlip INTO @c_LoadKey, @cBillToKey

      -- Handling transaction
      DECLARE @nTranCount INT
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN                    -- Begin our own transaction
      SAVE TRAN nsp_GetPickSlipCMC  -- For rollback or commit only our own transaction

      -- Loop each PickSlip
      WHILE @@FETCH_Status = 0
      BEGIN
         -- Added by Vicky on 09-Nov-2006 - Fix pickslipno generating (Start)
	      -- Reserve the PickSlipNo range
			SET @b_success = 1
			EXECUTE nspg_GetKey
	   		'PICKSLIP'
	   		, 9
	   		, @cPickSlipNo  OUTPUT
	   		, @b_success    OUTPUT
	   		, @n_err        OUTPUT
	   		, @c_errmsg     OUTPUT
	         , 0  -- Debug

	      IF @b_success <> 1 GOTO Quit
	      SET @cPickSlipNo = 'P' + @cPickSlipNo
         -- Added by Vicky on 09-Nov-2006 - Fix pickslipno generating (End)

         -- Insert PickHeader
         INSERT INTO PickHeader (PickHeaderKey, Consigneekey, ExternOrderKey, PickType, Zone, TrafficCop)
         VALUES (@cPickSlipNo, @cBillToKey, @c_LoadKey, '0', 'LB', '')
         IF @@ERROR <> 0 GOTO RollBackTran

         -- Stamp PickSlipNo in our temp table
         UPDATE #TempPickDetail SET 
            PickSlipNo = @cPickSlipNo
         WHERE #TempPickDetail.LoadKey = @c_LoadKey
            AND #TempPickDetail.BillToKey = @cBillToKey
         IF @@ERROR <> 0 GOTO RollBackTran

         -- Commented by Vicky on 09-Nov-2006 - Fix pickslipno generating (Start)
         -- Increment PickSlipNo
         --SET @cPickSlipNo = 'P' + RIGHT( REPLICATE( '0', 9) + CAST( CAST( RIGHT( @cPickSlipNo, 9) AS INT) + 1 AS NVARCHAR( 9)), 9)
         -- Commented by Vicky on 09-Nov-2006 - Fix pickslipno generating (End)

         FETCH NEXT FROM cur_PickSlip INTO @c_LoadKey, @cBillToKey
      END
      CLOSE cur_PickSlip
      DEALLOCATE cur_PickSlip

      -- Create RefKeyLookup
      INSERT INTO RefKeyLookup (OrderKey, OrderLineNumber, PickSlipNo, PickDetailKey, LoadKey)
      SELECT OrderKey, OrderLineNumber, PickSlipNo, PickDetailKey, LoadKey
      FROM #TempPickDetail
      ORDER BY PickDetailKey
      IF @@ERROR <> 0 GOTO RollBackTran

      -- Stamp PickSlipNo in PickDetail table
      UPDATE PickDetail SET 
         TrafficCop = NULL,
         PickSlipNo = #TempPickDetail.PickSlipNo
      FROM #TempPickDetail
      WHERE PickDetail.PickDetailKey = #TempPickDetail.PickDetailKey
      IF @@ERROR <> 0 GOTO RollBackTran
      
      COMMIT TRAN nsp_GetPickSlipCMC  -- Only commit change made in nsp_GetPickSlipCMC
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN 
   END

   -- Output the result
   SELECT #TempPickDetail.PickSlipNo, #TempPickDetail.LoadKey, #TempPickDetail.BillToKey,
      #TempPickDetail.SKU, QTY = SUM(#TempPickDetail.QTY),
      #TempPickDetail.LOC, 
      #TempPickDetail.ID, 
      #TempPickDetail.PackKey,
      #TempPickDetail.PrintedFlag,
      ISNULL(SKU.DESCR,'') SKUDESCR,
      UserDef1 = CONVERT(NVARCHAR(60), LP.Load_UserDef1), 
      UserDef2 = CONVERT(NVARCHAR(60), LP.Load_UserDef2), 
      #TempPickDetail.UOM, 
      LA.LOTtable02, 
      LA.LOTtable04,
      ISNULL(PACK.Casecnt, 0) CASECNT, 
      ISNULL(PACK.Innerpack, 0) Innerpack,
      ISNULL(PACK.Pallet, 0) Pallet,
      #TempPickDetail.StorerKey, 
      Storername = CO.Company, 
      Storer.Company, Storer.Address1, Storer.Address2, Storer.Address3,
      Weight = SUM(#TempPickDetail.QTY * SKU.StdGrosswgt),
      [Cube] = SUM(#TempPickDetail.QTY * SKU.StdCube),
      LOCType = LOC.LocationType,
      UserName = MAX( sUser_sName()),
      ISNULL( MAX( CONVERT( FLOAT, DATEDIFF( DAY, #TempPickDetail.AlLOCDate, (LA.LOTtable04 - ISNULL( CONVERT( INT, SKU.BUSR6), 0)))) / 30), 0),
      LOC.HostWhCode,
      LOC.LogicalLOCation
   FROM #TempPickDetail
      JOIN SKU (NOLOCK) ON #TempPickDetail.StorerKey = SKU.StorerKey AND #TempPickDetail.SKU = SKU.SKU
      JOIN PACK (NOLOCK) ON SKU.PackKey = PACK.PackKey
      JOIN Storer (NOLOCK) ON Storer.StorerKey = #TempPickDetail.BillToKey
      JOIN Storer CO (NOLOCK) ON CO.StorerKey = #TempPickDetail.StorerKey
      JOIN LOADPLAN LP (NOLOCK) ON #TempPickDetail.LoadKey = LP.LoadKey
      JOIN LOTATTRIBUTE LA (NOLOCK) ON #TempPickDetail.LOT = LA.LOT
      JOIN LOC (NOLOCK) ON #TempPickDetail.LOC = LOC.LOC
   GROUP BY 
      #TempPickDetail.PickSlipNo, 
      #TempPickDetail.LoadKey, 
      #TempPickDetail.BillToKey,
      #TempPickDetail.SKU,
      #TempPickDetail.LOC, 
      #TempPickDetail.ID, 
      #TempPickDetail.PackKey,
      #TempPickDetail.PrintedFlag,
      ISNULL(SKU.DESCR,''),
      CONVERT(NVARCHAR(60), LP.Load_UserDef1), 
      CONVERT(NVARCHAR(60), LP.Load_UserDef2),
      #TempPickDetail.UOM, 
      LA.LOTtable04, 
      LA.LOTtable02,
      ISNULL(PACK.Casecnt, 0), 
      ISNULL(PACK.Innerpack, 0), 
      ISNULL(PACK.Pallet, 0), 
      #TempPickDetail.AlLOCDate,
      Storer.Company, Storer.Address1, Storer.Address2, Storer.Address3, 
      LOC.LocationType, 
      CO.Company, 
      #TempPickDetail.StorerKey,
      LOC.HostWhCode, 
      LOC.LogicalLOCation
   ORDER BY #TempPickDetail.PickSlipNo, LOC.LocationType, LOC.HostWhCode, LOC.LogicalLOCation, #TempPickDetail.LOC, #TempPickDetail.SKU, #TempPickDetail.ID
-- added by James   SOS62253 - add sorting by pickslipno
   DROP TABLE #TempPickDetail
   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN nsp_GetPickSlipCMC -- Only rollback change made in nsp_GetPickSlipCMC
   WHILE @@TRANCOUNT > @nTranCount  -- Commit until the level we started
      COMMIT TRAN 
Quit:
END

GO