SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/*************************************************************************/    
/* Stored Procedure: isp_shipping_manifest_by_load_15                    */    
/* Creation Date:  2019-12-02                                            */    
/* Copyright: LFL                                                        */    
/* Written by:                                                           */    
/*                                                                       */    
/* Purpose:                  */    
/*                                                                       */    
/* Called By: r_shipping_manifest_by_load_15                             */    
/*                                                                       */    
/* PVCS Version: 1.1                                                     */    
/*                                                                       */    
/* Version: 5.4                                                          */    
/*                                                                       */    
/* Data Modifications:                                                   */    
/*                                                                       */    
/* Updates:                                                              */    
/* Date         Author  Ver   Purposes                                   */ 
/* 05-11-2021   Mingle  1.1   WMS-18305 Add new mappings(ML01)           */   
/*************************************************************************/    
CREATE PROC [dbo].[isp_shipping_manifest_by_load_15]    
(      
 @c_loadkey    NVARCHAR(10),
 @c_Type       NVARCHAR(10) = ''
)    
             
AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_DEFAULTS OFF      
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
       
   DECLARE @c_storerkey      NVARCHAR(15)    
          ,@n_NoOfLine       INT    
          ,@c_getstorerkey   NVARCHAR(10)    
          ,@c_getLoadkey     NVARCHAR(20)    
          ,@c_getOrderkey    NVARCHAR(20)    
          ,@c_getExtOrderkey NVARCHAR(20)  
          
   DECLARE @b_Success        INT
         , @n_Err            INT
         , @n_Continue       INT
         , @n_StartTCnt      INT
         , @c_ErrMsg         NVARCHAR(250)
         , @c_UserId         NVARCHAR(30)
         , @n_cnt            INT
         , @c_Getprinter     NVARCHAR(10) 
         , @c_GetDatawindow  NVARCHAR(50) = 'r_shipping_manifest_by_load_15'
         , @c_ReportID       NVARCHAR(10) = 'DELNOTE'

   SET @b_Success   = 1
   SET @n_Err       = 0
   SET @n_Continue  = 1
   SET @n_StartTCnt = @@TRANCOUNT
   SET @c_ErrMsg    = ''
   SET @c_UserId    = SUSER_SNAME()  

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   SELECT @c_Storerkey = MAX(OH.Storerkey)
   FROM LOADPLANDETAIL LPD (NOLOCK)
   JOIN ORDERS OH (NOLOCK) ON OH.ORDERKEY = LPD.ORDERKEY
   WHERE LPD.LOADKEY = @c_LoadKey

   SELECT @c_Getprinter = defaultprinter  
   FROM RDT.RDTUser AS r WITH (NOLOCK)  
   WHERE r.UserName = @c_UserId  

   --SET @c_Getprinter = 'Chooi02'

   IF @c_Type = NULL SET @c_Type = ''   

   IF @c_type = ''
   BEGIN
      BEGIN TRAN                            
      EXEC isp_PrintToRDTSpooler   
           @c_ReportType     = @c_ReportID,   --UCCLbConso 10 CHARS
           @c_Storerkey      = @c_Storerkey,  --18491'
           @b_success        = @b_success OUTPUT,  
           @n_err            = @n_err     OUTPUT,  
           @c_errmsg         = @c_errmsg  OUTPUT,  
           @n_Noofparam      = 2,  --2
           @c_Param01        = @c_LoadKey,  
           @c_Param02        = 'H1',  
           @c_Param03        = '',  
           @c_Param04        = '',  
           @c_Param05        = '',  
           @c_Param06        = '',  
           @c_Param07        = '',  
           @c_Param08        = '',  
           @c_Param09        = '',  
           @c_Param10        = '',  
           @n_Noofcopy       = 1,  
           @c_UserName       = @c_UserId,    --suser_sname()
           @c_Facility       = '',  
           @c_PrinterID      = @c_Getprinter,  --Printer from RDT.RDTUser
           @c_Datawindow     = @c_GetDatawindow,  --Datawindow name
           @c_IsPaperPrinter = 'Y'
   
      IF @b_success <> 1
      BEGIN
         ROLLBACK TRAN
         GOTO QUIT_SP
      END  
   
      WHILE @@TRANCOUNT > 0  
      BEGIN  
         COMMIT TRAN  
      END  

      SELECT NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
             NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
             'Printing Completed'
      GOTO QUIT_SP
   END
              
   CREATE TABLE #TMP_LoadOH11(    
          rowid           int identity(1,1),    
          storerkey       NVARCHAR(20) NULL,    
          loadkey         NVARCHAR(50) NULL,    
          Orderkey        NVARCHAR(10) NULL,    
          ExtOrdKey       NVARCHAR(60) NULL)               
        
   CREATE TABLE #TMP_SMBLOAD15 (    
          rowid           int identity(1,1),    
          Orderkey        NVARCHAR(20)  NULL,    
          loadkey         NVARCHAR(50)  NULL,    
          C_Company       NVARCHAR(45)  NULL,    
          SKU             NVARCHAR(20)  NULL,    
          SDESCR          NVARCHAR(150) NULL,    
          Lottable04      NVARCHAR(10)  NULL,    
          PQty            INT,    
          CaseCnt         FLOAT,    
          ExtOrdKey       NVARCHAR(60) NULL,      
          consigneekey    NVARCHAR(45) NULL,    
          C_Contact1      NVARCHAR(45) NULL,    
          C_Phone1        NVARCHAR(45) NULL,    
          CaseCnt2        INT,    
          PCS             INT,    
          STDNETWGT       FLOAT NULL,    
          StdCube         FLOAT NULL,    
          ST_Company      NVARCHAR(45) NULL,    
          C_Address1      NVARCHAR(45) NULL,    
          F_Address1      NVARCHAR(45) NULL,
          Userdefine02    NVARCHAR(20) NULL,    --ML01     
          Userdefine03    NVARCHAR(20) NULL,    --ML01
          Showfield       NVARCHAR(5)  NULL
          )           
       
  -- SET @n_NoOfLine = 6    
 
       
   IF EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK) WHERE Loadkey = @c_loadkey)    
   BEGIN    
      INSERT INTO #TMP_LoadOH11 (storerkey, loadkey, Orderkey,ExtOrdKey)    
      SELECT OH.Storerkey, OH.LoadKey,oh.OrderKey,oh.ExternOrderKey    
      FROM ORDERS OH (NOLOCK)    
      WHERE LoadKey = @c_loadkey     
   END    
   ELSE IF EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK) WHERE orderkey = @c_loadkey)    
   BEGIN    
      INSERT INTO #TMP_LoadOH11 (storerkey, loadkey, Orderkey,ExtOrdKey)    
      SELECT OH.Storerkey, OH.LoadKey,oh.OrderKey,oh.ExternOrderKey    
      FROM ORDERS OH (NOLOCK)    
      WHERE orderkey = @c_loadkey      
   END    
    
   DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR       SELECT DISTINCT Storerkey,loadkey,Orderkey,ExtOrdKey    
   FROM   #TMP_LoadOH11       
   --WHERE loadkey = @c_loadkey  -- (stv02)    
      
   OPEN CUR_RESULT       
         
   FETCH NEXT FROM CUR_RESULT INTO @c_getstorerkey,@c_getLoadkey,@c_getOrderkey,@c_getExtOrderkey        
         
   WHILE @@FETCH_STATUS <> -1      
   BEGIN        
        
      INSERT INTO #TMP_SMBLOAD15    
      (    
      -- rowid -- this column value is auto-generated    
          Orderkey,    
          loadkey,    
          C_Company,    
          SKU,    
          SDESCR,    
          Lottable04,    
          PQty,    
          CaseCnt,    
          ExtOrdKey,      
          consigneekey,    
          C_Contact1,    
          C_Phone1,    
          CaseCnt2,    
          PCS ,    
          STDNETWGT,    
          StdCube,    
          ST_company,C_Address1,F_Address1,
          Userdefine02,    --ML01
          Userdefine03,    --ML01   
          Showfield
      )    
      SELECT orders.orderkey,orders.loadkey,orders.c_company,    
             orderdetail.Sku,    
             RTRIM(sku.DESCR),    
             CONVERT(NVARCHAR(10),lot.lottable04,121) AS lottable04,    
             Sum(pickdetail.qty),    
             CASE WHEN L.locationtype<>'PICK' THEN SUM(pickdetail.qty) ELSE 0 END/pack.CaseCnt,    
             orders.ExternOrderKey,orders.consigneekey,    
             ISNULL(RTRIM(orders.c_Contact1), ''),    
             ISNULL(RTRIM(orders.C_Phone1), '') ,    
             ISNULL((pack.CaseCnt + CAST(isnull(sku.busr3,0) as int)),0),    
             CASE WHEN L.locationtype<>'PICK' THEN SUM(pickdetail.qty) ELSE 0 END % CAST(pack.casecnt as int) +    
             CASE WHEN L.locationtype='PICK' THEN SUM(pickdetail.qty) ELSE 0 END,    
             cast(Sum(pickdetail.qty)*sku.StdGrossWgt as decimal(9,4)),    
             case when sku.[Cube]>0 then Sum(pickdetail.qty) *sku.StdCube else Sum(pickdetail.qty) *sku.StdCube  end,
             storer.company,ISNULL(C_Address1,'') , ISNULL(F.Address1,'') ,
             orders.UserDefine02,    --ML01
             orders.UserDefine03,    --ML01   
             ISNULL(CL.SHORT,'')
      FROM Orders orders  WITH (nolock)    
      LEFT JOIN orderdetail orderdetail  WITH  (nolock) on orderdetail.orderkey = orders.orderkey     
      LEFT JOIN storer storer  WITH (nolock) on orders.storerkey = storer.storerkey     
      JOIN sku sku WITH (nolock) on orderdetail.storerkey=sku.storerkey and orderdetail.sku = sku.sku     
      JOIN pack pack  WITH (nolock) on pack.packkey = sku.packkey     
      LEFT JOIN PickDetail pickdetail  WITH  (nolock) on pickdetail.OrderKey=orderdetail.OrderKey and pickdetail.OrderLineNumber=orderdetail.OrderLineNumber    
      LEFT JOIN LotAttribute lot  WITH (nolock) on pickdetail.Lot=lot.Lot    
      JOIN LOC L WITH (NOLOCK) ON L.loc = pickdetail.loc    
      JOIN FACILITY F WITH (NOLOCK) ON F.facility = Orders.facility  
      LEFT JOIN CODELKUP CL WITH (NOLOCK) ON CL.LISTNAME = 'REPORTCFG' AND CL.Storerkey = orders.StorerKey AND CL.Long = 'r_shipping_manifest_by_load_15'
      WHERE orders.StorerKey = @c_getstorerkey    
      AND orders.LoadKey = @c_getLoadkey    
      AND orders.Orderkey = @c_getOrderkey    
      group by orders.orderkey,orders.loadkey,orders.c_company,    
               orderdetail.Sku,    
               RTRIM(sku.DESCR),    
               CONVERT(NVARCHAR(10),lot.lottable04,121) ,    
         -- Sum(pickdetail.qty),    
              (pack.CaseCnt + CAST(isnull(sku.busr3,0) as int)),    
              orders.ExternOrderKey,    
              ISNULL(RTRIM(orders.c_Contact1), ''),    
              ISNULL(RTRIM(orders.C_Phone1), '') ,L.locationtype,pack.CaseCnt,orders.consigneekey,    
              sku.StdGrossWgt,sku.[cube],sku.StdCube  ,storer.company,ISNULL(C_Address1,'') , ISNULL(F.Address1,''),    
     --      CASE WHEN L.locationtype<>'PICK' THEN SUM(pickdetail.qty) ELSE 0 END,    
     --      CASE WHEN L.locationtype<>'PICK' THEN SUM(pickdetail.qty) ELSE 0 END % CAST(p.casecnt as int) +    
     --CASE WHEN L.locationtype='PICK' THEN SUM(pickdetail.qty) ELSE 0 END,    
         --  cast(Sum(pickdetail.qty)*s.StdGrossWgt as decimal(9,4)),    
        --   case when s.[Cube]>0 then Sum(pickdetail.qty) *t3.StdCube else Sum(pickdetail.qty) *t3.StdCube  end
             orders.UserDefine02,    --ML01
             orders.UserDefine03,    --ML01 
             ISNULL(CL.SHORT,'')   
     
   ORDER BY orders.orderkey,orders.loadkey,orders.ExternOrderKey,orderdetail.Sku    
    
        
   FETCH NEXT FROM CUR_RESULT INTO @c_getstorerkey,@c_getLoadkey,@c_getOrderkey ,@c_getExtOrderkey     
   END       
         
   SELECT    
    ts.Orderkey,    
    CAST(ts.StdCube as decimal(10,2)) as StdCube,    
    ts.STDNETWGT,    
    ts.C_Contact1,    
    ts.C_Phone1,    
    ts.C_Company,    
    ts.loadkey,    
    ts.Lottable04,    
    ts.SKU,    
    ts.ExtOrdKey,      
    ts.PQty,    
    ts.ST_company,    
    ts.consigneekey,    
    ts.CaseCnt2,    
    ts.PCS,    
    ts.SDESCR,    
    FLOOR(ts.CaseCnt) as CaseCnt,ts.c_address1,ts.F_address1, --(stv03)    
    ROW_Number() OVER(PARTITION BY ts.Orderkey ORDER BY ts.Orderkey )  AS seqno, --(stv04) 
    ts.userdefine02,    --ML01
    ts.Userdefine03,    --ML01 
    ts.Showfield
   FROM #TMP_SMBLOAD15 AS ts    
  --  WHERE ts.loadkey = @c_loadkey    
   ORDER BY ts.loadkey,ts.Orderkey,ts.ExtOrdKey,ts.SKU    
        
QUIT_SP:    
   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END  



GO