SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Stored Proc: isp_GetPickSlipWave_37                                  */    
/* Creation Date: 01-MAR-2022                                           */    
/* Copyright: LF Logistics                                              */    
/* Written by: CSCHONG                                                  */    
/*                                                                      */    
/* Purpose:  WMS-18894 - [KR] COLLAGE_PickSlip by Order_New             */    
/*        :                                                             */    
/* Called By: r_dw_print_wave_pickslip_37                               */    
/*          :                                                           */    
/* GitLab Version: 1.1                                                  */    
/*                                                                      */    
/* Version: 7.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author    Ver Purposes                                  */     
/* 2022-03-01   CSCHONG   1.0 DevOps Combine Script                     */
/************************************************************************/  
CREATE PROC [dbo].[isp_GetPickSlipWave_37] (
   @c_wavekey          NVARCHAR(10)
)
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
   @c_pickheaderkey    NVARCHAR(10),
   @n_continue         INT,
   @c_errmsg           NVARCHAR(255),
   @b_success          INT,
   @n_err              INT,
   @c_sku              NVARCHAR(20),
   @n_qty              INT,
   @c_loc              NVARCHAR(10),
   @n_cases            INT,
   @n_perpallet        INT,
   @c_orderkey         NVARCHAR(10),
   @c_storer           NVARCHAR(15),
   @c_storercompany    NVARCHAR(45),
   @c_ConsigneeKey     NVARCHAR(15),
   @c_Company          NVARCHAR(45),
   @c_Addr1            NVARCHAR(45),
   @c_Addr2            NVARCHAR(45),
   @c_Addr3            NVARCHAR(45),
   @c_PostCode         NVARCHAR(15),
   @c_Route            NVARCHAR(10),
   @c_Route_Desc       NVARCHAR(60), -- RouteMaster.Desc
   @c_TrfRoom          NVARCHAR(10),  -- ORDERS.Door
   @c_Notes1           NVARCHAR(60),
   @c_Notes2           NVARCHAR(60),
   @c_SkuDesc          NVARCHAR(60),
   @n_CaseCnt          INT,
   @n_PalletCnt        INT,
   @n_InnerPack        INT,
   @c_ReceiptTm        NVARCHAR(20),
   @c_PrintedFlag      NVARCHAR(1),
   @c_UOM              NVARCHAR(10),
   @n_UOM3             INT,
   @c_Lot              NVARCHAR(10),
   @c_StorerKey        NVARCHAR(15),
   @c_Zone             NVARCHAR(1),
   @n_PgGroup          INT,
   @n_TotCases         INT,
   @n_RowNo            INT,
   @c_PrevSKU          NVARCHAR(20),
   @n_SKUCount         INT,
   @c_Carrierkey       NVARCHAR(60),
   @c_VehicleNo        NVARCHAR(10),
   @c_firstorderkey    NVARCHAR(10),
   @c_superorderflag   NVARCHAR(1),
   @c_firsttime        NVARCHAR(1),
   @c_logicalloc       NVARCHAR(18),
   @c_Lottable02       NVARCHAR(18),
   @c_Lottable03       NVARCHAR(18),
   @c_Lottable04       NVARCHAR(10),
   @c_labelPrice       NVARCHAR(5),
   @c_externorderkey   NVARCHAR(50), 
   @c_externpokey      NVARCHAR(20),
   @c_invoiceno        NVARCHAR(10),
   @d_deliverydate     DATETIME,
   @c_rdd              NVARCHAR(10),
   @c_putawayzone      NVARCHAR(10),
   @c_zonedesc         NVARCHAR(60),
   @c_busr8            NVARCHAR(30), 
   @c_AltSku           NVARCHAR(20), 
   @c_Susr1            NVARCHAR(20),
   @c_Susr2            NVARCHAR(20), 
   @n_StartTCnt        INT,
   @c_facility         NVARCHAR(1),  
   @c_WavePSlipQRCode  NVARCHAR(10), 
   @c_qrcode           NVARCHAR(1),  
   @c_showecomfield    NVARCHAR(1),  
   @c_Trackingno       NVARCHAR(30), 
   @c_Buyerpo          NVARCHAR(20),
   @c_Style            NVARCHAR(50),
   @c_Color            NVARCHAR(50),
   @c_Size             NVARCHAR(50),
   @c_AutoScanIn       NVARCHAR(10),
   @c_PickMethod       NVARCHAR(10),
   @n_TTLEA            INT = 0,
   @n_TTLCASES         INT = 0,
   @n_TTLQTY           INT = 0,
   @c_Priority         NVARCHAR(10) = '',
   @c_loadkey          NVARCHAR(20) = '' ,
   @c_OHTYPE           NVARCHAR(10) = '' ,
   @c_ODUpdateSource   NVARCHAR(20) = '' ,
   @c_ODPackkey        NVARCHAR(10) = '',
   @c_ODUOM            NVARCHAR(10)='',
   @c_ODNotes          NVARCHAR(500) = '' ,
   @c_OrdGrp           NVARCHAR(20) = '',
   @c_OHUDF03          NVARCHAR(20) = ''

 

    
   
   SET @n_StartTCnt = @@TRANCOUNT
   
   DECLARE @c_PrevOrderKey     NVARCHAR(10),
           @n_Pallets          INT,
           @n_Cartons          INT,
           @n_Eaches           INT,
           @n_UOMQty           INT
     
   CREATE TABLE #temp_wavepick37 (
      wavekey          NVARCHAR(10),  
      PrnDate          DATETIME NULL,
      PickSlipNo       NVARCHAR(10),
      Zone             NVARCHAR(1),   
      printedflag      NVARCHAR(1),   
      Storerkey        NVARCHAR(15) NULL, 
      LOC              NVARCHAR(10) NULL, 
      Lot              NVARCHAR(10),   
      OHType           NVARCHAR(10),  
      Loadkey          NVARCHAR(20),
    --  PLOC             NVARCHAR(10), 
      SkuDesc          NVARCHAR(60) NULL,
      Lottable04       NVARCHAR(10) NULL,   
      Qty              INT,     
      ODUpdateSource   NVARCHAR(20), 
      Susr1            NVARCHAR(20),
      Susr2            NVARCHAR(20),
      SKU              NVARCHAR(20) NULL, 
      rpttitle         NVARCHAR(80), 
      OrderKey         NVARCHAR(10),  
      OrdGrp           NVARCHAR(20) NULL,
      ODNotes          NVARCHAR(500) NULL,
      Packkey          NVARCHAR(10),
      UOM              NVARCHAR(10) NULL,
      UOMQty           INT,
      TTLEA            INT,
      TTLCASE          INT,
      TTLQTY           INT,
      OHUDF03          NVARCHAR(20)
   )
   
   SELECT @n_continue = 1
   SELECT @n_RowNo = 0
   SELECT @c_firstorderkey = 'N'
   
   -- Use Zone as a UOM Picked that refer to pickdetail.pickmethod
   IF EXISTS(SELECT 1 FROM PickHeader (NOLOCK) WHERE Wavekey = @c_wavekey AND orderkey IN (SELECT orderkey FROM Orders oh WITH (NOLOCK) WHERE oh.UserDefine09=@c_wavekey))
   BEGIN
      SELECT @c_firsttime = 'N'
      SELECT @c_printedflag = 'Y'
   END
   ELSE
   BEGIN
      SELECT @c_firsttime = 'Y'
      SELECT @c_printedflag = 'N'
   END -- Record Not Exists
   
   WHILE @@TRANCOUNT > 0
      COMMIT TRAN
        
   
   DECLARE pick_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT PickDetail.sku,       PickDetail.loc,
          SUM(PickDetail.qty),  PACK.Qty,
          PickDetail.storerkey, PickDetail.OrderKey,
          PickDetail.UOM,       Pickdetail.PickMethod,
          Pickdetail.Lot,
          Pickdetail.uomqty
   FROM   PickDetail WITH (NOLOCK)
   JOIN   Wavedetail WITH (NOLOCK) ON PickDetail.OrderKey = Wavedetail.OrderKey
   JOIN   PACK WITH (NOLOCK) ON PickDetail.Packkey = PACK.Packkey
   JOIN   LOC WITH (NOLOCK) ON LOC.Loc = PICKDETAIL.Loc
   JOIN   ORDERS WITH (NOLOCK) ON ORDERS.Orderkey = WaveDetail.Orderkey
                              AND ORDERS.Orderkey = PICKDETAIL.Orderkey
   JOIN   SKU WITH (NOLOCK) ON SKU.StorerKey = PICKDETAIL.Storerkey 
                           AND SKU.SKU = PICKDETAIL.Sku
   WHERE  Wavedetail.wavekey = @c_wavekey
   GROUP BY PickDetail.sku,  PickDetail.loc, PACK.Qty,
            PickDetail.storerkey, PickDetail.OrderKey, PICKDETAIL.UOM,
            Pickdetail.PickMethod,  Pickdetail.Lot,Pickdetail.uomqty
   ORDER BY PICKDETAIL.ORDERKEY
   
   OPEN pick_cur
   
   SELECT @c_PrevOrderKey = ''
   FETCH NEXT FROM pick_cur INTO @c_sku, @c_loc, @n_Qty, @n_uom3, @c_storerkey,
                                 @c_orderkey,  @c_UOM, @c_PickMethod, @c_lot,
                                 @n_UOMQty
   
   WHILE (@@FETCH_STATUS <> -1)
   BEGIN --While
      IF @c_OrderKey <> @c_PrevOrderKey
      BEGIN
         --SET @c_facility= '' 
         --SELECT @c_Facility = Facility
         --FROM ORDERS WITH (NOLOCK)
         --WHERE Orderkey = @c_OrderKey

        IF dbo.fnc_RTRIM(@c_OrderKey) = '' OR dbo.fnc_RTRIM(@c_OrderKey) IS NULL
      BEGIN  --if @c_orderkey = ''
         SELECT @c_ConsigneeKey = '',
                @c_externorderkey ='',
                @c_loadkey = '', 
                @c_Priority = '',
                @c_OHTYPE = '',
                @c_ODUpdateSource = '',
                @c_ODPackkey = '',
                @c_ODUOM     ='',
                @c_ODNotes   = '',
                @c_OrdGrp    = '',
                @c_OHUDF03   = ''     
      END  --if @c_orderkey=''
      ELSE
      BEGIN --if @c_orderkey <> ''
         SELECT @c_ConsigneeKey = Orders.consigneekey,
                @c_externorderkey = ORDERS.externorderkey,
                @c_loadkey = ORDERS.loadkey,
                @c_Priority = Orders.priority,
                @c_OHTYPE = ORDERS.type,
                @c_OrdGrp = ORDERS.OrderGroup,
                @c_OHUDF03 = ORDERS.userdefine03                                          
         FROM   ORDERS (NOLOCK) 
         WHERE  ORDERS.OrderKey = @c_OrderKey AND ORDERS.storerkey = @c_storerkey


         SELECT TOP 1  @c_ODUpdateSource = OD.UpdateSource,
                @c_ODPackkey = OD.PackKey,
                @c_ODUOM     = OD.UOM,
                @c_ODNotes   = ISNULL(OD.Notes,'')      
         FROM dbo.ORDERDETAIL OD WITH (NOLOCK)
         WHERE  OD.OrderKey = @c_OrderKey  
         AND OD.storerkey = @c_storerkey
         AND OD.sku = @c_sku

      END -- IF @c_OrderKey <> ''
   

         IF NOT EXISTS( SELECT 1 FROM PICKHEADER (NOLOCK) WHERE WaveKey = @c_wavekey AND OrderKey = @c_OrderKey AND ZONE =@c_PickMethod)
         BEGIN  --Not Exist in PickHeader
            EXECUTE nspg_GetKey
            'PICKSLIP',
            9,
            @c_pickheaderkey  OUTPUT,
            @b_success        OUTPUT,
            @n_err            OUTPUT,
            @c_errmsg         OUTPUT
   
            SELECT @c_pickheaderkey = 'P' + @c_pickheaderkey
         
            BEGIN TRAN
   
            INSERT INTO PICKHEADER
            (PickHeaderKey,    OrderKey, ExternOrderKey, StorerKey, ConsigneeKey, WaveKey,Priority, PickType, Zone,loadkey, TrafficCop)
            VALUES
            (@c_pickheaderkey, @c_OrderKey,@c_externorderkey,@c_storerkey,@c_ConsigneeKey, @c_wavekey,  @c_Priority,   '5', @c_PickMethod,  @c_loadkey,  '')
         
            SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               ROLLBACK TRAN
               GOTO QUIT
            END
            ELSE
            BEGIN
               WHILE @@TRANCOUNT > 0 
                  COMMIT TRAN
            END
   
            SELECT @c_firstorderkey = 'Y'
         END  --NOT EXIST in PICKHEADER
         ELSE
         BEGIN -- EXIST in PickHeader
            SELECT @c_pickheaderkey = PickHeaderKey 
            FROM  PickHeader (NOLOCK)
            WHERE WaveKey = @c_wavekey
            AND   Zone =  @c_PickMethod
            AND   OrderKey = @c_OrderKey
         END -- Exist in PickHeader
      END  -- @c_OrderKey <> @c_PrevOrderKey

   
      SELECT @c_SkuDesc = IsNULL(Descr,''),
             @c_Susr1  = IsNULL(SUSR1, ''),
             @c_Susr2 = IsNULL(SUSR2, '')
      FROM   SKU  (NOLOCK)
      WHERE  STorerKey = @c_StorerKey
      AND    SKU = @c_SKU
   
      SELECT  @c_Lottable04 = CONVERT(NVARCHAR(10),Lottable04,23) 
      FROM   LOTATTRIBUTE (NOLOCK)
      WHERE  LOT = @c_LOT
   
      
      SELECT @n_RowNo = @n_RowNo + 1
      SELECT @n_Pallets = 0,
            @n_Cartons = 0,
            @n_Eaches  = 0


      SET @n_TTLEA = 0
      SET @n_TTLCASES = 0
      SET @n_TTLQTY = 0

      IF @c_ODUOM = 'EA'
      BEGIN
        SELECT @n_TTLEA = SUM(PD.qty)
        FROM PICKDETAIL PD WITH (NOLOCK)
        JOIN dbo.ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.StorerKey = PD.Storerkey AND OD.sku = PD.Sku AND OD.OrderLineNumber = PD.OrderLineNumber
        WHERE PD.Storerkey = @c_storerkey AND PD.OrderKey = @c_orderkey AND OD.UOM = 'EA'
      END

     IF @c_ODUOM = 'CASE'
      BEGIN
        SELECT @n_TTLCASES = SUM(PD.uomQty)
        FROM PICKDETAIL PD WITH (NOLOCK)
        JOIN dbo.ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.StorerKey = PD.Storerkey AND OD.sku = PD.Sku AND OD.OrderLineNumber = PD.OrderLineNumber
        WHERE PD.Storerkey = @c_storerkey AND PD.OrderKey = @c_orderkey AND OD.UOM = 'CASE'
      END

     SELECT @n_TTLQTY = SUM(PD.qty) 
     FROM PICKDETAIL PD WITH (NOLOCK)
     WHERE PD.Storerkey = @c_storerkey AND PD.OrderKey = @c_orderkey


      INSERT INTO #temp_wavepick37
      (
          wavekey,
          PrnDate,
          PickSlipNo,
          Zone,
          printedflag,
          Storerkey,
          LOC,
          Lot,
          OHType,
          Loadkey,
      --    PLOC,
          SkuDesc,
          Lottable04,
          Qty,
          ODUpdateSource,
          Susr1,
          Susr2,
          SKU,
          rpttitle,
          OrderKey,
          OrdGrp,
          ODNotes,
          Packkey,
          UOM,
          UOMQty,
          TTLEA,
          TTLCASE,
          TTLQTY, 
          OHUDF03)
      VALUES
      (@c_wavekey,          CONVERT(CHAR(16), GetDate(), 120) ,  @c_pickheaderkey ,   @c_PickMethod  ,@c_printedflag, 
       @c_storerkey,        @c_LOC,                              @c_lot,              @c_OHTYPE,      @c_loadkey , 
       @c_SKUDesc,          @c_Lottable04,                       @n_Qty,              @c_ODUpdateSource,@c_Susr1,
       @c_Susr2 ,           @c_sku,                              'PickSlip by Orders' ,                 @c_OrderKey,      
       @c_OrdGrp,           @c_ODNotes,                          @c_ODPackkey ,       @c_ODUOM,         @n_UOMQty,
       @n_TTLEA,            @n_TTLCASES,                          @n_TTLQTY,          @c_OHUDF03                          
      )
      
      SELECT @c_PrevOrderKey = @c_OrderKey
   
     FETCH NEXT FROM pick_cur INTO @c_sku, @c_loc, @n_Qty, @n_uom3, @c_storerkey,
                                 @c_orderkey,  @c_UOM, @c_PickMethod, @c_lot,
                                 @n_UOMQty
   END
   
   CLOSE pick_cur
   DEALLOCATE pick_cur
   
   WHILE @@TRANCOUNT > 0
      COMMIT TRAN
        
      
SUCCESS:
  

   SELECT * FROM #temp_wavepick37 
   ORDER BY PickSlipNo, Orderkey, SKU

QUIT:

   IF OBJECT_ID('tempdb..#temp_wavepick37') IS NOT NULL
      DROP TABLE #temp_wavepick37


   WHILE @@TRANCOUNT < @n_StartTCnt
      BEGIN TRAN 

   IF @n_continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SELECT @b_success = 0  
      IF @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_StartTCnt  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_GetPickSlipWave_37'  
      -- RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      SELECT @b_success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN  
   END  
END
GRANT EXECUTE ON isp_GetPickSlipWave_37 TO NSQL 

GO