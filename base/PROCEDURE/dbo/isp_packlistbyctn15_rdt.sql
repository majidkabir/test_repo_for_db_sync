SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/  
/* Store Procedure: isp_PackListByCtn15_rdt                                   */  
/* Creation Date:14-JUNE-2019                                                 */  
/* Copyright: IDS                                                             */  
/* Written by: CSCHONG                                                        */  
/*                                                                            */  
/* Purpose: WMS-9265-CN - BoardRiders -BBG AU Packing List                    */  
/*        :                                                                   */  
/* Called By:  r_dw_packing_list_by_ctn15_rdt                                 */  
/*                                                                            */  
/* PVCS Version: 1.0                                                          */  
/*                                                                            */  
/* Version: 1.0                                                               */  
/*                                                                            */  
/* Data Modifications:                                                        */  
/*                                                                            */  
/* Updates:                                                                   */  
/* Date         Author    Ver.  Purposes                                      */
/* 05-SEP-2019  CSCHONG   1.1   WMS-9265 - revised field mapping (CS01)       */
/******************************************************************************/  
  
CREATE PROC [dbo].[isp_PackListByCtn15_rdt] (
         @c_PickSlipNo NVARCHAR(10))  
AS  
SET NOCOUNT ON
SET ANSI_WARNINGS OFF
SET QUOTED_IDENTIFIER OFF
SET CONCAT_NULL_YIELDS_NULL OFF  

BEGIN  
   DECLARE @n_continue        INT 
         , @n_starttcnt       INT
         , @b_success         INT  
         , @n_err             INT 
         , @c_errmsg        NVARCHAR(255)

         , @c_ExecSQLStmt     NVARCHAR(MAX)  
         , @c_ExecArguments   NVARCHAR(MAX) 
         
         , @n_Cnt             INT
         , @n_NoOfCarton      INT
         , @n_CartonNo        INT

         , @c_Logo1           NVARCHAR(60)
         , @c_Logo2           NVARCHAR(60)
         , @c_Logo3           NVARCHAR(60) 

         , @c_Orderkey        NVARCHAR(10)  
         , @c_LabelNo         NVARCHAR(20)
         , @c_Storerkey       NVARCHAR(15)            
         , @c_Style           NVARCHAR(20)
         , @c_Color           NVARCHAR(10)
         , @c_Busr3           NVARCHAR(30) 
         , @c_Busr4           NVARCHAR(30) 
         , @c_Size            NVARCHAR(5) 
         , @c_D_Userdefine03  NVARCHAR(18)  
         , @c_D_Userdefine05  NVARCHAR(18)  
         , @n_Qty             INT
         , @n_TTLPACKWGT      FLOAT 
 
   SET @n_continue      = 1
   SET @n_starttcnt     = @@TRANCOUNT
   SET @b_success       = 1
   SET @n_err           = 0
   SET @c_Errmsg        = ''

   SET @c_ExecSQLStmt   = ''  
   SET @c_ExecArguments = ''

   SET @n_Cnt           = 0
   SET @n_CartonNo      = 0
   SET @n_NoOfCarton    = 0

   SET @c_Logo1         = ''
   SET @c_Logo2         = ''
   SET @c_Logo3         = ''

   SET @c_Orderkey      = ''
   SET @c_LabelNo       = ''
   SET @c_Storerkey     = ''
   SET @c_Style         = ''
   SET @c_Color         = ''
   SET @c_Busr3         = ''
   SET @c_Busr4         = ''
   SET @c_Size          = ''
   SET @c_D_Userdefine03= ''
   SET @c_D_Userdefine05= ''
   SET @n_Qty           = 0
   SET @n_TTLPACKWGT    = 0.00  --CS01

   CREATE Table #TempPackListByCtn15rdt (
                 OrderKey           NVARCHAR(10) NULL 
               , ExternOrderkey     NVARCHAR(50) NULL 
               , ORD_MCompany       NVARCHAR(45) NULL 
               , ORD_Address1       NVARCHAR(45) NULL
               , Phone1             NVARCHAR(18) NULL 
               , SKU                NVARCHAR(20) NULL
               , carrierref2        NVARCHAR(40) NULL 
               , PackQty            INT 
               , ORD_Company        NVARCHAR(45) NULL
               , ORD_Address2       NVARCHAR(45) NULL    
               , LabelNo            NVARCHAR(20) NULL 
               , SDESCR             NVARCHAR(60) NULL 
               , STDGROSSWGT        FLOAT  
               , ORD_MAddress1      NVARCHAR(45) NULL
               , SSTYLE             NVARCHAR(20) NULL
               , SITEMCLASS         NVARCHAR(10) NULL
               , SBUSR8             NVARCHAR(30) NULL
               , ORD_CCity          NVARCHAR(45) NULL
               , ORD_CState         NVARCHAR(45) NULL
               , ORD_CZip           NVARCHAR(45) NULL
               , ORD_MAddress2      NVARCHAR(45) NULL
               , ORDBuyerPO         NVARCHAR(20) NULL
               , ORD_MCity          NVARCHAR(45) NULL     
    ) 
   INSERT INTO #TempPackListByCtn15rdt (
               OrderKey             
               , ExternOrderkey     
               , ORD_MCompany       
               , ORD_Address1       
               , Phone1           
               , SKU                          
               , carrierref2            
               , PackQty             
               , ORD_Company        
               , ORD_Address2             
               , LabelNo            
               , SDESCR             
               , STDGROSSWGT           
               , ORD_MAddress1            
               , SSTYLE              
               , SITEMCLASS        
               , SBUSR8
               , ORD_CCity
               , ORD_CState
               , ORD_CZip
               , ORD_MAddress2 
               , ORDBuyerPO
               , ORD_MCity)
     SELECT ORDERS.OrderKey,   
            RTRIM(UPPER(ORDERS.ExternOrderKey)),
            ORDERS.Salesman,   
            ISNULL(ORDERS.C_Address1,''),   
            ST.Phone1,   
            PackDetail.SKU, 
            CT.Carrierref2,   
            SUM(Packdetail.Qty) as PackQty ,
            ISNULL(ORDERS.C_Company,''), 
            ISNULL(ORDERS.C_Address2,''),
            PackDetail.LabelNo,
            (ISNULL(RTRIM(SKU.DESCR),'') + Space(2) + SKU.size), 
            0.0 ,--SKU.STDGROSSWGT, 
            ISNULL(ORDERS.M_Address1,''),
            SKU.style,
            SKU.ItemClass,
            ISNULL(SKU.BUSR8,''),
            ISNULL(ORDERS.C_City,'') , 
            ISNULL(ORDERS.C_State,'') , 
            ISNULL(ORDERS.C_Zip,''),
            ISNULL(ORDERS.M_Address2,''),
            ORDERS.BuyerPO,ISNULL(ORDERS.M_City,'')  
    FROM ORDERS (NOLOCK)   
    JOIN PACKHEADER WITH (NOLOCK) ON (ORDERS.OrderKey = PACKHEADER.OrderKey)
    JOIN PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)
    JOIN SKU (NOLOCK) ON ( PackDetail.Sku = SKU.Sku AND PackDetail.StorerKey = SKU.StorerKey )
    JOIN STORER ST (NOLOCK) ON ( ST.Storerkey = ORDERS.storerkey )  
   JOIN CARTONTRACK CT WITH (NOLOCK) ON CT.labelno = PackDetail.labelno                                        
   WHERE ( RTRIM(PackHeader.OrderKey) IS NOT NULL AND RTRIM(PackHeader.OrderKey) <> '') and 
         ( Packheader.Pickslipno = @c_PickSlipNo) AND ORDERS.Ordergroup='AU' and ORDERS.Type='PNP'
GROUP BY ORDERS.OrderKey,   
         RTRIM(UPPER(ORDERS.ExternOrderKey)),   
         ORDERS.Salesman,   
         ISNULL(ORDERS.C_Address1,''),   
         ST.Phone1,   
         PackDetail.SKU, 
         ISNULL(ORDERS.C_Address2,''),   
         CT.Carrierref2,
         ISNULL(ORDERS.C_Company,''), 
         PackDetail.LabelNo,
         (ISNULL(RTRIM(SKU.DESCR),'') + Space(2) + SKU.size),  
         SKU.STDGROSSWGT, 
         ISNULL(ORDERS.M_Address1,''),
         SKU.style,
         SKU.ItemClass,
         ISNULL(SKU.BUSR8,''),
         ISNULL(ORDERS.C_City,'') , 
         ISNULL(ORDERS.C_State,'') , 
         ISNULL(ORDERS.C_Zip,''),
         ISNULL(ORDERS.M_Address2,''),
         ORDERS.BuyerPO,ISNULL(ORDERS.M_City,'')                        
       
       --CS01 START
       SELECT @n_TTLPACKWGT = SUM(weight)
       FROM PACKINFO WITH (NOLOCK)
       WHERE Pickslipno = @c_PickSlipNo 

       Update t
         Set t.STDGROSSWGT = @n_TTLPACKWGT
         From
          (
            Select Top 1 STDGROSSWGT
            From #TempPackListByCtn15rdt
            --Where pickslipno = @c_PickSlipNo
           ORDER BY ExternOrderkey,LabelNo,SSTYLE
        ) t
   --CS01 END
   SELECT *
   FROM #TempPackListByCtn15rdt            
   ORDER BY ExternOrderkey,LabelNo,SSTYLE   
          

   DROP TABLE #TempPackListByCtn15rdt
END  


GO