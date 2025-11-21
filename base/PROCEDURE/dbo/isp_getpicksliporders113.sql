SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: isp_GetPickSlipOrders113                                    */
/* Creation Date: 21-Sep-2020                                           */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-15179-PH_Novateur_PickList_CR                           */
/*          Notes: Duplicate from nsp_GetPickSlipOrders04d and modified */
/*                                                                      */
/* Input Parameters:   @c_loadkey   - Loadkey                           */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Return Status:                                                       */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: r_dw_print_pickorder113                                   */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/*01-NOV-2020   CSCHONG   1.1   WMS-15179 revised sorting (CS01)        */
/*11-Nov-2020   WLChooi   1.2   WMS-15676 - Add new column (WL01)       */
/************************************************************************/

CREATE PROC [dbo].[isp_GetPickSlipOrders113] (@c_wavekey NVARCHAR(20))
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @c_orderkey      NVARCHAR(10),
            @c_getorderkey   NVARCHAR(10),
            @c_getloadkey    NVARCHAR(20),
            @c_getwavekey    NVARCHAR(20),
            @c_pickslipno    NVARCHAR(10),
            @c_getpickslipno NVARCHAR(10),
            @c_invoiceno     NVARCHAR(10),
            @c_storerkey     NVARCHAR(18),
            @c_getstorerkey  NVARCHAR(18),
            @b_success       int,
            @n_err           int,
            @c_errmsg        NVARCHAR(255),
            @n_Continue      INT,
            @n_StartTCnt     INT,
            @c_printbyWave   NVARCHAR(20),
            @c_printbyload   NVARCHAR(20)

   SET @n_Continue = 1
   SET @c_printbyWave = 'N'
   SET @c_printbyload = 'N'

   CREATE TABLE #TEMP_Load_113 (
      Loadkey       NVARCHAR(10),
      wavekey       NVARCHAR(10)
   )
  CREATE INDEX IDX_#TEMP_Load_113_wave ON #TEMP_Load_113(loadkey,wavekey)  

  IF EXISTS (SELECT 1 FROM WAVE WITH (NOLOCK) WHERE Wavekey = @c_wavekey)
  BEGIN
     SET @c_printbyWave = 'Y' 
  -- INSERT INTO #TEMP_Load_113
  -- SELECT DISTINCT OH.Loadkey, WD.wavekey
  -- FROM WAVEDETAIL WD (NOLOCK)
  -- JOIN ORDERS OH (NOLOCK) ON WD.Orderkey = OH.Orderkey
  ---- LEFT JOIN PICKHEADER PH (NOLOCK) ON PH.Loadkey = LPD.Loadkey
  -- WHERE WD.Wavekey = @c_WaveKey
 END
 ELSE IF EXISTS (SELECT 1 FROM LOADPLANDETAIL WITH (NOLOCK) WHERE loadkey = @c_wavekey)
 BEGIN 
  -- INSERT INTO #TEMP_Load_113
  -- SELECT DISTINCT LPD.Loadkey, WD.wavekey
  -- FROM WAVEDETAIL WD (NOLOCK)
  -- JOIN LOADPLANDETAIL LPD (NOLOCK) ON WD.Orderkey = LPD.Orderkey
  ---- LEFT JOIN PICKHEADER PH (NOLOCK) ON PH.Loadkey = LPD.Loadkey
  -- WHERE LPD.loadkey = @c_WaveKey
   SET @c_printbyload = 'Y'
 END
--select @c_printbyload '@c_printbyload',@c_printbyWave '@c_printbyWave'
IF @c_printbyload ='N' AND @c_printbyWave ='N'
BEGIN

  GOTO QUIT_SP
END
--select * from #TEMP_Load_113
SELECT PICKDETAIL.PickSlipNo as Pickslipno,
      PICKDETAIL.Lot,   
      PICKDETAIL.Loc, 
      PICKDETAIL.ID, 
      PickedQty=SUM(PICKDETAIL.Qty),      
      SKU.DESCR,   
      SKU.Sku,   
      SKU.STDNETWGT,   
      SKU.STDCUBE,   
      SKU.STDGROSSWGT,  
      LOTATTRIBUTE.Lottable02,   
      LOTATTRIBUTE.Lottable03,   
      LOTATTRIBUTE.Lottable04,
      ORDERS.InvoiceNo,
      ORDERS.OrderKey,   
      ORDERS.LoadKey,
      ORDERS.StorerKey,   
      ORDERS.ConsigneeKey,   
      STORER.Company,   
      ORDERS.DeliveryDate,              
      ORDERS.BuyerPO,   
      ORDERS.ExternOrderKey,               
      ORDERS.Route,   
      ORDERS.Stop,   
      ORDERS.Door,           
      ORDERS.C_CONTACT1,
      ORDERS.BilltoKey, 
      PACK.CaseCnt,       
      PACK.PackUOM1,   
      PACK.PackUOM3,
      PACK.Qty,      
      PACK.PackUOM4,  
      PACK.Pallet,    
      ORDERS.b_company as B_company,
      ISNULL(ORDERS.b_address1,'') as B_address1,
      ISNULL(ORDERS.b_address2,'') as B_address2,
      ISNULL(ORDERS.b_address3,'') as B_address3,
      ISNULL(ORDERS.b_address4,'') as B_address4,
      ORDERS.c_company as C_company,
      ISNULL(ORDERS.c_address1,'') as C_address1,
      ISNULL(ORDERS.c_address2,'') as C_address2,
      ISNULL(ORDERS.c_address3,'') as C_address3,
      ISNULL(ORDERS.c_address4,'') as C_address4,
      ORDERS.PrintFlag,
      Notes=CONVERT(NVARCHAR(250),ORDERS.Notes),
      Prepared = CONVERT(NVARCHAR(10), Suser_Sname()),
      ORDERS.LoadKey as Rdd, 
      sku.susr3,
      CODELKUP.description as principal,
      ORDERS.Facility, 
      FacilityDescr = Facility.Descr, 
      Custbarcode = '',--CONVERT(NVARCHAR(15),BILLTO.Notes1), 
      ISNULL(SKU.Busr6, 0) as Busr6,  
      LOC.LogicalLocation, 
      PACK.InnerPack,
      SKU.RetailSku,
      Loadplan.Route AS LRoute,                                                 
      Loadplan.Externloadkey AS LEXTLoadKey,                                     
      Loadplan.Priority AS LPriority,                                           
      Loadplan.LPuserdefDate01 AS LPuserdefDate01,
      ORDERS.Userdefine02 as OHUDF02 ,
      ORDERS.type as OHType,
      ORDERS.Notes2 as OHNotes2 ,
      OIF.notes AS OIFNotes ,
      CASE WHEN ISNULL(SKU.SerialNocapture,'') = '1' THEN 'Y' ELSE 'N'  END  AS SN,
      ORDERS.Userdefine01 as OHUDF01,SKU.skuGroup AS SkuGrp,
      ORDERDETAIL.UOM as ODUOM,
      CASE WHEN ORDERDETAIL.UOM = PACK.PACKUOM1 THEN SUM(PICKDETAIL.Qty)/NULLIF(PACK.CASECNT,0) 
           WHEN ORDERDETAIL.UOM = PACK.PACKUOM2 THEN SUM(PICKDETAIL.Qty)/NULLIF(PACK.INNERPACK,0)  
           WHEN ORDERDETAIL.UOM = PACK.PACKUOM3 THEN SUM(PICKDETAIL.Qty)/NULLIF(PACK.Qty,0) 
           WHEN ORDERDETAIL.UOM = PACK.PACKUOM4 THEN SUM(PICKDETAIL.Qty)/NULLIF(PACK.Pallet,0) ELSE 0 END as UOMQTY
    ,ORDERS.userdefine09 as wavekey
    ,ISNULL(SKU.OVAS,'') AS OVAS   --WL01
    ,CASE WHEN TRIM(ORDERS.[Type]) IN ('STO','STR') THEN ISNULL(ORDERS.UserDefine03,'') ELSE '' END AS OHUDF03   --WL01
    ,ISNULL(ORDERS.OrderGroup,'') AS OrderGroup   --WL01
    ,ISNULL(ORDERS.PmtTerm,'') AS PmtTerm         --WL01
   INTO  #RESULT_113
   FROM  LOC (Nolock) 
   join PICKDETAIL (Nolock)
      ON LOC.Loc = PICKDETAIL.Loc
   JOIN ORDERS (Nolock)
      ON ORDERS.OrderKey = PICKDETAIL.OrderKey
   JOIN STORER (Nolock)
      ON ORDERS.StorerKey = STORER.StorerKey
   --LEFT OUTER JOIN STORER billto (nolock)
   --   ON billto.storerkey = ORDERS.billtokey
   --LEFT OUTER JOIN STORER consignee (nolock)
   --   ON consignee.storerkey = ORDERS.consigneekey
   JOIN SKU (Nolock)
      ON SKU.StorerKey = PICKDETAIL.Storerkey and
         SKU.Sku = PICKDETAIL.Sku
   JOIN LOTATTRIBUTE (Nolock)
      ON PICKDETAIL.Lot = LOTATTRIBUTE.Lot
   JOIN PACK (Nolock) 
      ON PACK.PackKey = SKU.PackKey
   JOIN ORDERDETAIL (NOLOCK)
      ON PICKDETAIL.orderkey = ORDERDETAIL.orderkey and
         PICKDETAIL.orderlinenumber = ORDERDETAIL.orderlinenumber
      AND PICKDETAIL.sku = ORDERDETAIL.sku
   LEFT OUTER JOIN CODELKUP (nolock)
      ON codelkup.listname = 'PRINCIPAL' and
         codelkup.code = sku.susr3
   INNER JOIN FACILITY (nolock) 
      ON Facility.Facility = ORDERS.Facility -- Add by June 11.Jun.03 (SOS11736)
   JOIN LOADPLAN WITH (NOLOCK)                      
      ON LOADPLAN.loadkey = ORDERDETAIL.loadkey   
   LEFT JOIN ORDERINFO OIF WITH (NOLOCK) ON OIF.orderkey = ORDERS.Orderkey
   --LEFT JOIN #TEMP_Load_113 TL113 ON TL113.loadkey = ORDERS.loadkey   
   WHERE ORDERS.loadkey = CASE WHEN @c_printbyload = 'Y' THEN @c_wavekey ELSE ORDERs.loadkey END
   AND ORDERS.userdefine09 = CASE WHEN @c_printbywave = 'Y' THEN @c_wavekey ELSE ORDERS.userdefine09 END
   GROUP BY 
      PICKDETAIL.PickSlipNo,
      PICKDETAIL.Lot,  
      PICKDETAIL.ID, 
      PICKDETAIL.Loc,    
      SKU.DESCR,   
      SKU.Sku,   
      SKU.STDNETWGT,   
      SKU.STDCUBE,   
      SKU.STDGROSSWGT,  
      LOTATTRIBUTE.Lottable02,   
      LOTATTRIBUTE.Lottable03,   
      LOTATTRIBUTE.Lottable04,
      ORDERS.InvoiceNo,
      ORDERS.OrderKey,
      ORDERS.LoadKey,
      ORDERS.StorerKey,   
      ORDERS.ConsigneeKey,   
      STORER.Company,   
      ORDERS.DeliveryDate,              
      ORDERS.BuyerPO,   
      ORDERS.ExternOrderKey,               
      ORDERS.Route,   
      ORDERS.Stop,   
      ORDERS.Door,           
      ORDERS.C_CONTACT1,
      ORDERS.BilltoKey, 
      PACK.CaseCnt,       
      PACK.PackUOM1,  
      PACK.PackUOM2, 
      PACK.PackUOM3,
      PACK.Qty,      
      PACK.PackUOM4,  
      PACK.Pallet,    
      ORDERS.b_company,
      ISNULL(ORDERS.b_address1,''),
      ISNULL(ORDERS.b_address2,''),
      ISNULL(ORDERS.b_address3,''),
      ISNULL(ORDERS.b_address4,''),
      ORDERS.c_company,
      ISNULL(ORDERS.c_address1,''),
      ISNULL(ORDERS.c_address2,''),
      ISNULL(ORDERS.c_address3,''),
      ISNULL(ORDERS.c_address4,''),
      ORDERS.PrintFlag,
      CONVERT(NVARCHAR(250),ORDERS.Notes),
      -- ORDERS.Rdd,
      sku.susr3,
      CODELKUP.description,
      ORDERS.Facility, 
      Facility.Descr, 
      --CONVERT(NVARCHAR(15), BILLTO.Notes1), 
      SKU.Busr6, -- SOS37766
      LOC.LogicalLocation, 
      -- process PICKSLIPNO
      PACK.InnerPack ,
      SKU.RetailSku,
      Loadplan.Route ,                                              
      Loadplan.Externloadkey ,                                        
      Loadplan.Priority ,                                            
      Loadplan.LPuserdefDate01 ,
      ORDERS.Userdefine02 ,
      ORDERS.type,ORDERS.notes2 ,
      OIF.notes,
      CASE WHEN ISNULL(SKU.SerialNocapture,'') = '1' THEN 'Y' ELSE 'N'  END,
      ORDERS.Userdefine01,SKU.skuGroup ,ORDERDETAIL.uom       ,ORDERS.userdefine09,
      ISNULL(SKU.OVAS,''),   --WL01
      CASE WHEN TRIM(ORDERS.[Type]) IN ('STO','STR') THEN ISNULL(ORDERS.UserDefine03,'') ELSE '' END,   --WL01
      ISNULL(ORDERS.OrderGroup,''),   --WL01
      ISNULL(ORDERS.PmtTerm,'')      --WL01

   DECLARE CUR_PSLIP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT DISTINCT Loadkey, Pickslipno,wavekey,Orderkey,storerkey 
      FROM #RESULT_113
      WHERE pickslipno is null or pickslipno = ''
      ORDER BY wavekey,loadkey,Orderkey

      OPEN CUR_PSLIP  
     
      FETCH NEXT FROM CUR_PSLIP INTO @c_getLoadkey, @c_getpickslipno,@c_getwavekey,@c_getorderkey,@c_getstorerkey

      WHILE @@FETCH_STATUS <> -1  
      BEGIN             
   
   --select @c_orderkey = ''
   --while (1=1)
   --begin -- while 1
      --select @c_orderkey = min(orderkey)
      --from #RESULT_113
      --where orderkey > @c_orderkey
      --   and (pickslipno is null or pickslipno = '')

      --if isnull(@c_orderkey, '0') = '0'
      --   break
      
      --select @c_storerkey = storerkey
      --from #RESULT_113
      --where orderkey = @c_orderkey
    --IF ISNULL(@c_getpickslipno,'') = ''
    --BEGIN
      EXECUTE nspg_GetKey
         'PICKSLIP',
         9,   
         @c_pickslipno     OUTPUT,
         @b_success      OUTPUT,
         @n_err          OUTPUT,
         @c_errmsg       OUTPUT

        IF @b_Success <> 1 
        BEGIN
         SET @n_Continue = 3
         SET @n_Err = 89010
         SET @c_Errmsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Error Executing nspg_GetKey. (isp_GetPickSlipOrders113)'
         GOTO QUIT_SP
       END


      SELECT @c_pickslipno = 'P' + @c_pickslipno            
    -- END
      -- Start : SOS31698, Add by June 31.Jan.2005
      -- Honielot request to update the previous P/S# so that same SO# only has 1 P/S#
      -- This is to prevent scanning of previous P/S#
      IF EXISTS (SELECT 1 FROM PICKHEADER (NOLOCK) 
                 WHERE Orderkey = @c_getorderkey AND Wavekey = @c_getwavekey AND loadkey = @c_getloadkey AND zone = '3'
                 AND   PICKHEADER.PickHeaderkey <> @c_pickslipno)
      BEGIN
         DELETE FROM PICKHEADER WHERE Orderkey = @c_getorderkey AND Wavekey = @c_getwavekey AND loadkey = @c_getloadkey AND zone = '3'
      END
      -- End : SOS31698

      INSERT PICKHEADER (pickheaderkey, wavekey, orderkey, zone,loadkey)
            VALUES (@c_pickslipno,@c_getwavekey , @c_getorderkey, '3',@c_getloadkey)

      -- update PICKDETAIL
      UPDATE PICKDETAIL
      SET trafficcop = null,
          pickslipno = @c_pickslipno
      WHERE orderkey = @c_getorderkey

      -- update print flag
      --UPDATE ORDERS
      --SET trafficcop = null,
      --    printflag = 'Y'
      --WHERE orderkey = @c_orderkey

      if exists (select 1 
                 from storerconfig (nolock)
                 where storerkey = @c_getstorerkey
                    and configkey in ('WTS-ITF','LORITF')
                    and svalue = '1')
         -- update result table
        BEGIN
         UPDATE #RESULT_113
         SET pickslipno = @c_pickslipno,
               rdd = @c_getloadkey
         WHERE orderkey = @c_getorderkey
      END
      ELSE
      BEGIN
         UPDATE #RESULT_113
         SET pickslipno = @c_pickslipno
         WHERE orderkey = @c_getorderkey
      END
   --end -- while 1
   FETCH NEXT FROM CUR_PSLIP INTO @c_getLoadkey, @c_getpickslipno,@c_getwavekey,@c_getorderkey,@c_getstorerkey
   END
   -- return result set
   SELECT * FROM #RESULT_113
   Order by Pickslipno,orderkey,
            CASE WHEN logicallocation <> '' THEN 0 ELSE 1 END,logicallocation,loc
           -- CASE WHEN logicallocation = '' THEN loc ELSE logicallocation END
   -- drop table
   DROP TABLE #RESULT_113

QUIT_SP:
   IF OBJECT_ID('#RESULT_113') IS NOT NULL
      DROP TABLE #RESULT_113

   IF @n_continue=3 -- Error Occured - Process And Return
   BEGIN
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_GetPickSlipOrders113' 
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012 
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END 
      RETURN
   END
END

GO