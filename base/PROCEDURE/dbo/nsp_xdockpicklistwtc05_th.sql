SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  nsp_XDockPickListWTC05_th                          */
/* Creation Date: 16-Jan-2006                                           */
/* Copyright: IDS                                                       */
/* Written by: MaryVong                                                 */
/*                                                                      */
/* Purpose:  Create Bacth Pickslip for IDSPH WTC Indent (SOS45186)      */
/*           Note: 1) Copy from nsp_XDockPickListWTC03 and modified     */
/*                 2) Do not limit to Loclevel < 4                      */
/*                                                                      */
/* Input Parameters:  @c_loadkey - Loadkey                              */
/*                                                                      */
/* Usage:  Used for report dw = r_dw_xdock_pick_wtc05_th                */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Purposes                                     */
/* 20-Jan-2006  MaryVong   SOS45342 Allow to reprint and assign new     */
/*                         pickslipno for re-allocated orderdetail      */
/* 07-Jul-2006  Vanessa    SOS110331 Requirement as below:				*/
/*1)	Page Break of the report will be by Putaway Zone				*/
/*2)	Report sorting by Putaway Zone, LogicalLocation, Location Code, SKU */
/*3)	Report will be printed after completed order allocation process */
/*4)	RCM at LoadPlan Header Screen				        (Vanessa01) */
/* 10-Jul-2008  Vanessa    Solved insert null pickslipno at RefKeyLookup*/
/*                         (Vanessa02)                                  */
/* 21-Jul-2008  Vanessa    Solved duplicate data at report by sum qty   */
/*                         (Vanessa03)                                  */
/* 28-Jul-2008  Vanessa    SOS110331 Changed Requirement as below:      */
/*  1	Change Page Break of the report from break by Putaway Zone to break by Loc.LocAisle */
/*  2   Change Sub Total by SKU to Total by Loc.LocAisle                */
/*  3   If same SKU please show the data same record        (Vanessa04) */
/************************************************************************/

CREATE PROC [dbo].[nsp_XDockPickListWTC05_th] (@a_s_LoadKey NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON			-- SQL 2005 Standard
   SET QUOTED_IDENTIFIER OFF	
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF        

   DECLARE
      @c_ReprintFlag   NVARCHAR(1),   -- SOS45342 To indicate reprint
      @n_err           int,
      @n_continue      int,
      @n_cnt           int,
	  @n_count         int,
      @c_PickHeaderKey NVARCHAR(10),
      @c_PickSlipNo    NVARCHAR(10),
      @b_success       int,
      @c_errmsg        NVARCHAR(255),
      @n_starttcnt     int,
      @n_intcnt        int, 
      @b_debug         NVARCHAR(1), 
      @c_SKU           NVARCHAR(20), 
      @c_row           NVARCHAR(10) 

   SELECT 
      @c_ReprintFlag   = '' ,
      @n_err           = 0 ,
      @n_continue      = 1 ,
      @n_cnt           = 0 ,
      @n_count         = 0 ,
      @c_PickSlipNo    = '' ,
      @b_success       = 0 ,
      @c_errmsg        = '' ,
      @n_starttcnt     = @@TRANCOUNT ,
      @n_intcnt        = 0 , 
      @b_debug         = 0 , 
      @c_SKU           = '' ,
      @c_row           = '0' 

	--(Vanessa01)
	SELECT Loc.LocAisle,   -- (Vanessa04)
		  Loc.PutawayZone,
		  @a_s_LoadKey AS Loadkey,
		  Orders.ConsigneeKey,
		  LOADPLAN.Delivery_Zone,
		  LOADPLAN.Route,
          PickDetail.SKU,
          SKU.Descr, 
		  SKU.RetailSKU,
		  substring(PickDetail.loc,1,1)+'-'+
		  substring(PickDetail.loc,2,2)+'-'+
		  substring(PickDetail.loc,4,2)+'-'+
		  substring(PickDetail.loc,6,2)+'-'+
		  substring(PickDetail.loc,8,3)as Loc,
          PickDetail.PickSlipNo,
          Pack.InnerPack,
          Pack.CaseCnt,
		  Pack.PackDescr,
	      PickDetail.Qty,
		  PickDetail.UOM,
          OrderDetail.OrderKey,
          OrderDetail.OrderLineNumber,
          PickDetail.PickDetailkey,
          OrderDetail.Storerkey,
          Pack.Pallet,
          -- SOS45342
          PrintedFlag =  			 
          CASE WHEN PickDetail.PickSlipNo IS NULL THEN 'N'
			    WHEN PickDetail.PickSlipNo = '' THEN 'N' 
				 ELSE 'Y'
			 END, 
          Loc.LogicalLocation,
          UserID= sUser_sName()
     INTO #IndentPickDetail
     FROM PickDetail WITH (NOLOCK)
     JOIN OrderDetail WITH (NOLOCK) ON (PickDetail.OrderKey = OrderDetail.OrderKey
          AND PickDetail.OrderLineNumber = OrderDetail.OrderLineNumber)
     JOIN SKUXLoc SXL WITH (NOLOCK) ON (PickDetail.Loc = SXL.Loc AND SXL.SKU = PickDetail.SKU 
          AND SXL.Storerkey = PickDetail.storerkey)
     JOIN Loc WITH (NOLOCK) ON (SXL.Loc = Loc.Loc)
     JOIN PACK WITH (NOLOCK) ON (PickDetail.Packkey = PACK.Packkey)
     JOIN SKU WITH (NOLOCK) ON (SKU.StorerKey = OrderDetail.StorerKey AND SKU.SKU = OrderDetail.SKU)
     JOIN Orders WITH (NOLOCK) ON (OrderDetail.Orderkey = Orders.Orderkey)
     JOIN CODELKUP WITH (NOLOCK) ON (Orders.Type = CODELKUP.Code AND CODELKUP.Listname = 'WTCORDTYPE'
                                AND CODELKUP.Short = 'BATCH')
	 JOIN LOADPLAN WITH (NOLOCK) ON (OrderDetail.LoadKey = LOADPLAN.LoadKey)
    WHERE OrderDetail.LoadKey = @a_s_LoadKey 
      AND PickDetail.Qty > 0
      AND PickDetail.Status < '5'  --(Vanessa01)

   SELECT @n_cnt = @@ROWCOUNT
   IF @n_cnt = 0 
	   SELECT @n_continue = 4
   ELSE
      SELECT @n_intcnt = @n_cnt

   -- Zone = 'LP' for GROUND (Pickface)
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN  
      IF EXISTS(SELECT 1 FROM PickHeader WITH (NOLOCK) WHERE ExternOrderKey = @a_s_LoadKey AND Zone = 'LP')
      BEGIN
         -- SOS45342
         SELECT @c_ReprintFlag = 'Y'
		   SELECT @c_row = MAX(Convert(int,WaveKey)) FROM PickHeader WITH (NOLOCK) 
		   WHERE ExternOrderKey = @a_s_LoadKey AND Zone = 'LP' 
      END
      ELSE
      BEGIN
         SELECT @c_ReprintFlag = 'N'
         SELECT @c_row = '0'
      END -- Record Not Exists

      SET NOCOUNT ON    
      UPDATE PickHeader
         SET TrafficCop = NULL
       WHERE ExternOrderKey = @a_s_LoadKey
         AND Zone = 'LP'

      SELECT @n_err = @@ERROR
      IF @n_err <> 0 
      BEGIN
         SELECT @n_continue = 3
      END
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN  
      IF @b_debug = 1 SELECT 'Started 1st Cursor Sku...'

      DECLARE CurSku CURSOR LOCAL FAST_FORWARD READ_ONLY FOR

      SELECT DISTINCT Sku FROM #IndentPickDetail WITH (NOLOCK)
      WHERE (PickSlipNo IS NULL OR PickSlipNo = '')   -- SOS45342
        AND PrintedFlag = 'N'                         -- SOS45342
       ORDER BY Sku

      OPEN CurSku 
      FETCH NEXT FROM CurSku INTO @c_SKU  

      WHILE @@FETCH_STATUS <> -1  -- CurSku Loop 
      BEGIN
         IF @@FETCH_STATUS = 0
         BEGIN
            IF @n_continue = 1 OR @n_continue = 2
            BEGIN
               EXECUTE dbo.nspg_GetKey
                      'PICKSLIP', 9, @c_PickHeaderKey OUTPUT, @b_success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT

               IF @b_success = 0
                  SELECT @n_continue = 3
               ELSE
               BEGIN
                  SELECT @c_PickHeaderKey = 'P' + @c_PickHeaderKey

                  SELECT @c_row = CONVERT(CHAR(10), CONVERT(INT, @c_row) + 1) 

                  INSERT INTO PICKHEADER (PickHeaderKey, WaveKey, ExternOrderKey, Zone, TrafficCop)   
                  VALUES (@c_PickHeaderKey, @c_row, @a_s_LoadKey, 'LP', '')

                  SELECT @n_err = @@ERROR
                  IF @n_err <> 0 
                     SELECT @n_continue = 3
               END
            END

            IF @n_continue = 1 OR @n_continue = 2
            BEGIN   
               UPDATE #IndentPickDetail 
                  SET PickSlipNo = @c_PickHeaderKey 
                WHERE Sku = @c_SKU 
			       AND   (PickSlipNo IS NULL OR PickSlipNo = '') 

               UPDATE PickDetail
                  SET PickSlipNo = @c_PickHeaderKey,
                      Trafficcop = NULL
                 FROM PickDetail WITH (NOLOCK)
                 JOIN OrderDetail WITH (NOLOCK) ON (PickDetail.OrderKey = OrderDetail.OrderKey AND 
                                               PickDetail.OrderLineNumber = OrderDetail.OrderLineNumber)
                 JOIN SKUXLoc SXL WITH (NOLOCK) ON (PickDetail.Loc = SXL.Loc AND SXL.SKU = PickDetail.SKU AND 
                                               SXL.Storerkey = PickDetail.Storerkey)
                 JOIN Loc WITH (NOLOCK) ON (SXL.Loc = Loc.Loc)
                WHERE OrderDetail.LoadKey = @a_s_LoadKey 
                  AND OrderDetail.Sku = @c_SKU 
                  AND PickDetail.Qty > 0
                  AND PickDetail.Status < '5'
			         AND (PickSlipNo IS NULL OR PickSlipNo = '')  -- SOS45342

                  SELECT @n_err = @@ERROR
                  IF @n_err <> 0 
                     SELECT @n_continue = 3
            END

            IF (@n_continue = 1 OR @n_continue = 2) 
            BEGIN            
              INSERT INTO RefKeyLookup (OrderKey, OrderLineNumber, PickslipNo, PickDetailkey, Loadkey)
              SELECT OrderKey, OrderLineNumber, PickSlipNo, PickDetailkey, LoadKey    --(Vanessa02) 
                FROM #IndentPickDetail 
               WHERE Sku = @c_SKU
				     AND PrintedFlag = 'N' -- SOS45342
               ORDER BY PickDetailkey 

              SELECT @n_err = @@ERROR
              IF @n_err <> 0 
                 SELECT @n_continue = 3
            END

         END -- IF @@FETCH_STATUS = 0 - 1st CurSku

         FETCH NEXT FROM CurSku INTO @c_SKU  
      END -- WHILE @@FETCH_STATUS <> -1 -- CurSku Loop 

      SELECT @c_row = '0'

      CLOSE CurSku 
      DEALLOCATE CurSku

   END -- IF @n_continue = 1 OR @n_continue = 2  


   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_starttcnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_starttcnt
         BEGIN
            COMMIT TRAN
         END
      END
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
   END

   IF @n_intcnt >= 1 AND (@n_continue = 3 OR @n_continue = 4)
      DELETE FROM #IndentPickDetail

	  --(Vanessa01) -- (Vanessa03)
	  SELECT #IndentPickDetail.LocAisle,   -- (Vanessa04)
		  #IndentPickDetail.PutawayZone,
		  #IndentPickDetail.Loadkey,
		  #IndentPickDetail.ConsigneeKey,
		  #IndentPickDetail.Delivery_Zone,
		  #IndentPickDetail.Route,
          #IndentPickDetail.SKU,
          #IndentPickDetail.Descr, 
		  #IndentPickDetail.RetailSKU,
		  #IndentPickDetail.Loc,
          #IndentPickDetail.PickSlipNo,
          #IndentPickDetail.InnerPack,
          #IndentPickDetail.CaseCnt,
		  #IndentPickDetail.PackDescr,
	      sum(#IndentPickDetail.Qty) as QtyAllocated,
		  #IndentPickDetail.UOM,
          '',
          '',
          '',
          '',
          '',
          #IndentPickDetail.PrintedFlag, 
          #IndentPickDetail.LogicalLocation,
          #IndentPickDetail.UserID,
		  @c_ReprintFlag   -- SOS45342
	  FROM #IndentPickDetail 
	  GROUP BY #IndentPickDetail.LocAisle,  -- (Vanessa04)
		  #IndentPickDetail.PutawayZone,
		  #IndentPickDetail.Loadkey,
		  #IndentPickDetail.ConsigneeKey,
		  #IndentPickDetail.Delivery_Zone,
		  #IndentPickDetail.Route,
          #IndentPickDetail.SKU,
          #IndentPickDetail.Descr, 
		  #IndentPickDetail.RetailSKU,
		  #IndentPickDetail.Loc,
          #IndentPickDetail.PickSlipNo,
          #IndentPickDetail.InnerPack,
          #IndentPickDetail.CaseCnt,
		  #IndentPickDetail.PackDescr,
		  #IndentPickDetail.UOM,
          #IndentPickDetail.PrintedFlag, 
          #IndentPickDetail.LogicalLocation,
          #IndentPickDetail.UserID
	  ORDER BY #IndentPickDetail.PutawayZone, 
    		 #IndentPickDetail.LogicalLocation,
			 #IndentPickDetail.Loc,
			 #IndentPickDetail.SKU
	  --(Vanessa01) -- (Vanessa03)

   SET NOCOUNT OFF
   DROP TABLE #IndentPickDetail
END /* main procedure */

GO