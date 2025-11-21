SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store Procedure:  isp_GetPackList03_ps                               */  
/* Creation Date: 19-Sep-2023                                           */  
/* Copyright: Maersk                                                    */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose:  WMS-23542-[TW] PUMA B2B Packing List_PB Report_New         */  
/*           (modified from isp_GetPackList03                           */  
/*                                                                      */  
/* Usage:  Used for report dw = r_dw_print_packlist_03_ps               */  
/*                                                                      */  
/* Called By: Exceed                                                    */  
/*                                                                      */  
/* PVCS Version: 1.3                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author  Ver.  Purposes                                  */  
/* 19-Sep-2023 CSCHONG  1.0   Devops Scripts Combine                    */ 
/************************************************************************/  
  
CREATE   PROC [dbo].[isp_GetPackList03_ps] (@c_pickslipno NVARCHAR(10))   
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @b_debug int  
   SELECT @b_debug = 0  
     
   DECLARE @c_OrderKey        NVARCHAR(10),  
           @c_SkuSize         NVARCHAR(5),  
           @c_TempOrderKey    NVARCHAR(10),  
           @c_PrevOrderKey    NVARCHAR(10),  
           @c_Style           NVARCHAR(20),                                                          
           @c_Color           NVARCHAR(10),                                                    
           @c_PrevStyle       NVARCHAR(20),                                                    
           @c_PrevColor       NVARCHAR(10),                                                      
           @c_SkuSort         NVARCHAR(3),                                                        
           @b_success         int,  
           @n_err             int,  
           @c_errmsg          NVARCHAR(255),  
           @n_Count           int,  
           @c_SkuSize1        NVARCHAR(5),  
           @c_SkuSize2        NVARCHAR(5),  
           @c_SkuSize3        NVARCHAR(5),  
           @c_SkuSize4        NVARCHAR(5),  
           @c_SkuSize5        NVARCHAR(5),  
           @c_SkuSize6        NVARCHAR(5),  
           @c_SkuSize7        NVARCHAR(5),  
           @c_SkuSize8        NVARCHAR(5),  
           @c_SkuSize9        NVARCHAR(5),  
           @c_SkuSize10       NVARCHAR(5),  
           @c_SkuSize11       NVARCHAR(5),  
           @c_SkuSize12       NVARCHAR(5),  
           @c_SkuSize13       NVARCHAR(5),  
           @c_SkuSize14       NVARCHAR(5),  
           @c_SkuSize15       NVARCHAR(5),  
           @c_SkuSize16       NVARCHAR(5),  
           @c_SkuSize17       NVARCHAR(5),  
           @c_SkuSize18       NVARCHAR(5),  
           @c_SkuSize19       NVARCHAR(5),  
           @c_SkuSize20       NVARCHAR(5),  
           @c_SkuSize21       NVARCHAR(5),  
           @c_SkuSize22       NVARCHAR(5),  
           @c_SkuSize23       NVARCHAR(5),  
           @c_SkuSize24       NVARCHAR(5),  
           @c_SkuSize25       NVARCHAR(5),  
           @c_SkuSize26       NVARCHAR(5),  
           @c_SkuSize27       NVARCHAR(5),  
           @c_SkuSize28       NVARCHAR(5),  
           @c_SkuSize29       NVARCHAR(5),  
           @c_SkuSize30       NVARCHAR(5),  
           @c_SkuSize31       NVARCHAR(5),  
           @c_SkuSize32       NVARCHAR(5)   
  
         , @n_NonPumaExternSO    INT                     
         , @n_ShowReportName     INT                     
         , @n_ShowOrderDate      INT                     
         , @n_ShowFullConsignee  INT                     
         , @c_Storerkey          NVARCHAR(15)            
         , @c_ShowField          NVARCHAR(1) 
         , @c_LoadKey            NVARCHAR(10)      
         , @c_GetOrderkey        NVARCHAR(20)  
         , @c_PHStatus           NVARCHAR(5)
  
   
   SET @c_Style      = ''                                                                            
   SET @c_Color      = ''                                                                            
   SET @c_PrevStyle  = ''                                                                             
   SET @c_PrevColor  = ''                                                                            
   SET @c_SkuSort    = ''        
     
   SET @n_NonPumaExternSO = 0                         
   SET @n_ShowReportName  = 0                         
   SET @n_ShowOrderDate   = 0                         
   SET @n_ShowFullConsignee = 0                       
   SET @c_Storerkey  = ''                             
     
  
   CREATE TABLE #TempPickSlip  
          (PickSlipNo         NVARCHAR(10)   NULL,  
           Loadkey            NVARCHAR(10)   NULL,  
           OrderKey           NVARCHAR(10)   NULL,  
           ExternOrderKey     NVARCHAR(50)   NULL,   --tlting_ext  
           Notes              NVARCHAR(255)  NULL,  
           ConsigneeKey       NVARCHAR(15)   NULL,  
           Company            NVARCHAR(45)   NULL,  
           c_Address1         NVARCHAR(45)   NULL,  
           c_Address2         NVARCHAR(45)   NULL,  
           c_Address3         NVARCHAR(45)   NULL,  
           c_Address4         NVARCHAR(45)   NULL,       
           C_City             NVARCHAR(45)   NULL,  
           C_Zip              NVARCHAR(18)   NULL,  
           Stylecolor         NVARCHAR(30)   NULL,  
           SkuDescr           NVARCHAR(60)   NULL,                 
           StorerNotes        NVARCHAR(255)  NULL,  
           Qty                INT            NULL,           
           UOM                NVARCHAR(10)   NULL,  
           CaseCnt            float,  
           lpuserdefdate01    datetime       NULL,  
           Storerkey          NVARCHAR(15)   NULL,  
           SkuSize1           NVARCHAR(5)    NULL,  
           SkuSize2           NVARCHAR(5)    NULL,  
           SkuSize3           NVARCHAR(5)    NULL,  
           SkuSize4           NVARCHAR(5)    NULL,  
           SkuSize5           NVARCHAR(5)    NULL,  
           SkuSize6           NVARCHAR(5)    NULL,  
           SkuSize7           NVARCHAR(5)    NULL,  
           SkuSize8           NVARCHAR(5)    NULL,  
           SkuSize9           NVARCHAR(5)    NULL,  
           SkuSize10          NVARCHAR(5)    NULL,  
           SkuSize11          NVARCHAR(5)    NULL,  
           SkuSize12          NVARCHAR(5)    NULL,  
           SkuSize13          NVARCHAR(5)    NULL,  
           SkuSize14          NVARCHAR(5)    NULL,  
           SkuSize15          NVARCHAR(5)    NULL,  
           SkuSize16          NVARCHAR(5)   NULL,  
           SkuSize17          NVARCHAR(5)    NULL,  
           SkuSize18          NVARCHAR(5)    NULL,  
           SkuSize19          NVARCHAR(5)    NULL,  
           SkuSize20          NVARCHAR(5)    NULL,  
           SkuSize21          NVARCHAR(5)    NULL,  
           SkuSize22          NVARCHAR(5)    NULL,  
           SkuSize23          NVARCHAR(5)    NULL,  
           SkuSize24          NVARCHAR(5)    NULL,  
           SkuSize25          NVARCHAR(5)    NULL,  
           SkuSize26          NVARCHAR(5)    NULL,  
           SkuSize27          NVARCHAR(5)    NULL,  
           SkuSize28          NVARCHAR(5)    NULL,  
           SkuSize29          NVARCHAR(5)    NULL,  
           SkuSize30          NVARCHAR(5)    NULL,  
           SkuSize31          NVARCHAR(5)    NULL,  
           SkuSize32          NVARCHAR(5)    NULL,  
           Qty1               int           NULL,  
           Qty2               int           NULL,  
           Qty3               int           NULL,  
           Qty4               int           NULL,  
           Qty5               int           NULL,  
           Qty6               int           NULL,  
           Qty7               int           NULL,  
           Qty8               int           NULL,  
           Qty9               int           NULL,  
           Qty10              int            NULL,  
           Qty11              int            NULL,  
           Qty12              int            NULL,  
           Qty13              int            NULL,  
           Qty14              int            NULL,  
           Qty15              int            NULL,  
           Qty16              int            NULL,  
           Qty17              int            NULL,  
           Qty18              int            NULL,  
           Qty19              int            NULL,  
           Qty20              int            NULL,  
           Qty21              int            NULL,  
           Qty22              int            NULL,  
           Qty23              int            NULL,  
           Qty24              int            NULL,  
           Qty25              int            NULL,  
           Qty26              int            NULL,  
           Qty27              int            NULL,  
           Qty28              int            NULL,  
           Qty29              int            NULL,  
           Qty30              int            NULL,  
           Qty31              int            NULL,  
           Qty32              int            NULL  
         , NonPumaExternSO    NVARCHAR(100)  NULL  
         , ShowReportName     INT            NULL  
         , ShowFullConsignee  INT            NULL  
         , ShowOrderDate      INT            NULL  
         , OrderDate          DATETIME       NULL  
         , ShowField          NVARCHAR(1)    NULL     
         )  
  
   SELECT @c_TempOrderKey = '', @n_Count = 0        
   SELECT @c_SkuSize1='',  @c_SkuSize2='',  @c_SkuSize3='',  @c_SkuSize4=''  
   SELECT @c_SkuSize5='',  @c_SkuSize6='',  @c_SkuSize7='',  @c_SkuSize8=''  
   SELECT @c_SkuSize9='',  @c_SkuSize10='', @c_SkuSize11='', @c_SkuSize12=''  
   SELECT @c_SkuSize13='', @c_SkuSize14='', @c_SkuSize15='', @c_SkuSize16=''    
   SELECT @c_SkuSize17='', @c_SkuSize18='', @c_SkuSize19='', @c_SkuSize20=''  
   SELECT @c_SkuSize21='', @c_SkuSize22='', @c_SkuSize23='', @c_SkuSize24=''    
   SELECT @c_SkuSize25='', @c_SkuSize26='', @c_SkuSize27='', @c_SkuSize28=''  
   SELECT @c_SkuSize29='', @c_SkuSize30='', @c_SkuSize31='', @c_SkuSize32=''    

      SELECT @c_Loadkey  = loadkey   
            ,@c_GetOrderkey = OrderKey
            ,@c_PHStatus = Status
      FROM PackHeader (NOLOCK) 
      WHERE PickSlipNo=@c_pickslipno
  
   SELECT DISTINCT OrderKey  
   INTO #TempOrder  
   FROM  LOADPLANDETAIL (NOLOCK)  
   WHERE LOADPLANDETAIL.LoadKey   = @c_LoadKey     
   AND   LoadPlanDetail.OrderKey  = @c_GetOrderkey

IF @c_PHStatus <> '9'
BEGIN
    GOTO QUIT_SP
END
  
   WHILE (1=1)  --AND @c_PHStatus = '9'
   BEGIN  
      SELECT @c_TempOrderKey = MIN(OrderKey)  
      FROM #TempOrder  
      WHERE OrderKey > @c_TempOrderKey  
   
      IF @c_TempOrderKey IS NULL OR @c_TempOrderKey = ''  BREAK  
  
  
      SELECT @c_Storerkey = Storerkey  
      FROM ORDERS WITH (NOLOCK)  
      WHERE Orderkey = @c_TempOrderKey  
  
      SET @n_NonPumaExternSO = 0  
      SET @n_ShowReportName  = 0  
      SET @n_ShowOrderDate   = 0  
      SET @n_ShowFullConsignee = 0  
      SET @c_ShowField = ''  
  
      SELECT @n_NonPumaExternSO= MAX(CASE WHEN Code = 'NonPumaExternSO' THEN 1 ELSE 0 END)  
            ,@n_ShowReportName = MAX(CASE WHEN Code = 'ShowReportName' THEN 1 ELSE 0 END)  
            ,@n_ShowOrderDate  = MAX(CASE WHEN Code = 'ShowOrderDate' THEN 1 ELSE 0 END)  
            ,@n_ShowFullConsignee = MAX(CASE WHEN Code = 'ShowFullConsignee' THEN 1 ELSE 0 END)  
            ,@c_ShowField   =  MAX(CASE WHEN ISNULL(Code,'') <> '' THEN 'Y' ELSE 'N' END)          
      FROM CODELKUP WITH (NOLOCK)  
      WHERE ListName = 'REPORTCFG'  
      AND Storerkey = @c_Storerkey  
      AND Long = 'r_dw_print_packlist_03_ps'  
      AND (Short IS NULL OR Short <> 'Y')  
 
  
      -- Get all unique sizes for the same order   
      DECLARE pick_cur CURSOR FAST_FORWARD READ_ONLY FOR  
      SELECT DISTINCT                                                                                 
             ISNULL(RTRIM(SKU.Size),'')                                                               
            , OD.Orderkey   
            ,ISNULL(RTRIM(SKU.Style),'')                                                               
            ,ISNULL(RTRIM(SKU.Color),'')                                                               
            ,RIGHT(ISNULL(RTRIM(SKU.SKU),''),3)                                                       
      FROM ORDERDETAIL OD (NOLOCK)   
      JOIN LOADPLANDETAIL LP (NOLOCK) ON (LP.Orderkey = OD.Orderkey)  
      JOIN SKU (NOLOCK) ON (SKU.SKU = OD.SKU AND SKU.Storerkey = OD.Storerkey)  
      WHERE OD.OrderKey = @c_TempOrderKey  
      AND OD.Loadkey = @C_Loadkey                                                                 
      ORDER BY OD.OrderKey   
            ,  ISNULL(RTRIM(SKU.Style),'')                                                             
            ,  ISNULL(RTRIM(SKU.Color),'')                                                             
            ,  RIGHT(ISNULL(RTRIM(SKU.SKU),''),3)                                                     
            ,  ISNULL(RTRIM(SKU.Size),'')                                                             
  
      OPEN pick_cur  
      FETCH NEXT FROM pick_cur INTO @c_SkuSize, @c_OrderKey  
                                 ,  @c_Style                                                           
                                 ,  @c_Color                                                           
                                 ,  @c_SkuSort                                                        
  
      WHILE (@@FETCH_STATUS <> -1)  
      BEGIN  
   SELECT @n_Count = @n_Count + 1  
   IF @b_debug = 1  
   BEGIN  
    SELECT 'Count of sizes is ' + CONVERT(char(5), @n_Count)  
   END  
     
   SELECT @c_SkuSize1 = CASE @n_Count WHEN 1  
                      THEN @c_SkuSize  
                      ELSE @c_SkuSize1  
                      END   
   SELECT @c_SkuSize2 = CASE @n_Count WHEN 2  
                      THEN @c_SkuSize  
                      ELSE @c_SkuSize2  
                      END  
   SELECT @c_SkuSize3 =  CASE @n_Count WHEN 3  
                      THEN @c_SkuSize  
                      ELSE @c_SkuSize3  
                      END   
   SELECT @c_SkuSize4 =  CASE @n_Count WHEN 4  
                      THEN @c_SkuSize  
                      ELSE @c_SkuSize4  
                      END  
   SELECT @c_SkuSize5 =  CASE @n_Count WHEN 5  
                      THEN @c_SkuSize  
                      ELSE @c_SkuSize5  
                      END   
   SELECT @c_SkuSize6 =  CASE @n_Count WHEN 6  
                      THEN @c_SkuSize  
                      ELSE @c_SkuSize6  
      END  
   SELECT @c_SkuSize7 =  CASE @n_Count WHEN 7  
                      THEN @c_SkuSize  
                      ELSE @c_SkuSize7  
                      END   
   SELECT @c_SkuSize8 =  CASE @n_Count WHEN 8  
                      THEN @c_SkuSize  
                      ELSE @c_SkuSize8  
                      END  
   SELECT @c_SkuSize9 =  CASE @n_Count WHEN 9  
                      THEN @c_SkuSize  
                      ELSE @c_SkuSize9  
                      END   
   SELECT @c_SkuSize10 = CASE @n_Count WHEN 10  
                      THEN @c_SkuSize  
                      ELSE @c_SkuSize10  
                      END  
   SELECT @c_SkuSize11 = CASE @n_Count WHEN 11  
                      THEN @c_SkuSize  
                      ELSE @c_SkuSize11  
                      END   
   SELECT @c_SkuSize12 = CASE @n_Count WHEN 12  
                      THEN @c_SkuSize  
                      ELSE @c_SkuSize12  
                      END  
   SELECT @c_SkuSize13 = CASE @n_Count WHEN 13  
                      THEN @c_SkuSize  
                      ELSE @c_SkuSize13  
                      END   
   SELECT @c_SkuSize14 = CASE @n_Count WHEN 14  
                      THEN @c_SkuSize  
                      ELSE @c_SkuSize14  
                      END  
   SELECT @c_SkuSize15 = CASE @n_Count WHEN 15  
                      THEN @c_SkuSize  
                      ELSE @c_SkuSize15  
                      END   
   SELECT @c_SkuSize16 = CASE @n_Count WHEN 16  
                      THEN @c_SkuSize  
                      ELSE @c_SkuSize16  
                      END  
   SELECT @c_SkuSize17 = CASE @n_Count WHEN 17  
                      THEN @c_SkuSize  
                      ELSE @c_SkuSize17  
                      END    
   SELECT @c_SkuSize18 = CASE @n_Count WHEN 18  
                      THEN @c_SkuSize  
                      ELSE @c_SkuSize18  
                      END    
   SELECT @c_SkuSize19 = CASE @n_Count WHEN 19  
                      THEN @c_SkuSize  
                      ELSE @c_SkuSize19  
                      END    
   SELECT @c_SkuSize20 = CASE @n_Count WHEN 20  
                      THEN @c_SkuSize  
                      ELSE @c_SkuSize20  
                      END    
   SELECT @c_SkuSize21 = CASE @n_Count WHEN 21  
                      THEN @c_SkuSize  
                      ELSE @c_SkuSize21  
                      END    
   SELECT @c_SkuSize22 = CASE @n_Count WHEN 22  
                      THEN @c_SkuSize  
                      ELSE @c_SkuSize22  
                      END    
   SELECT @c_SkuSize23 = CASE @n_Count WHEN 23  
                      THEN @c_SkuSize  
                      ELSE @c_SkuSize23  
                      END    
   SELECT @c_SkuSize24 = CASE @n_Count WHEN 24  
                      THEN @c_SkuSize  
                      ELSE @c_SkuSize24  
                      END    
   SELECT @c_SkuSize25 = CASE @n_Count WHEN 25  
                      THEN @c_SkuSize  
                      ELSE @c_SkuSize25  
                      END    
   SELECT @c_SkuSize26 = CASE @n_Count WHEN 26  
                      THEN @c_SkuSize  
                      ELSE @c_SkuSize26  
                      END    
   SELECT @c_SkuSize27 = CASE @n_Count WHEN 27  
                      THEN @c_SkuSize  
                      ELSE @c_SkuSize27  
                      END    
   SELECT @c_SkuSize28 = CASE @n_Count WHEN 28  
                      THEN @c_SkuSize  
                      ELSE @c_SkuSize28  
                      END    
   SELECT @c_SkuSize29 = CASE @n_Count WHEN 29  
                      THEN @c_SkuSize  
                      ELSE @c_SkuSize29  
                      END    
   SELECT @c_SkuSize30 = CASE @n_Count WHEN 30  
                      THEN @c_SkuSize  
                      ELSE @c_SkuSize30  
                      END    
   SELECT @c_SkuSize31 = CASE @n_Count WHEN 31  
                      THEN @c_SkuSize  
                      ELSE @c_SkuSize31  
                      END    
   SELECT @c_SkuSize32 = CASE @n_Count WHEN 32  
                      THEN @c_SkuSize  
                      ELSE @c_SkuSize32  
                      END    
                                      
   SELECT @c_PrevOrderKey = @c_OrderKey  
         SET @c_PrevStyle = @c_Style                                                                   
         SET @c_PrevColor = @c_Color                                                                   
         
   FETCH NEXT FROM pick_cur INTO @c_SkuSize, @c_OrderKey  
                                    ,  @c_Style                                                        
                                    ,  @c_Color                                                        
                                    ,  @c_SkuSort                                                     
     
   IF @b_debug = 1  
   BEGIN  
   SELECT 'PrevOrderkey= ' + @c_PrevOrderKey + ', Orderkey= ' + @c_OrderKey  
   END  
     
   IF (@c_PrevOrderKey <> @c_OrderKey) OR   
            (@c_PrevStyle <> @c_Style) OR                                                              
            (@c_PrevColor <> @c_Color) OR                                                             
     (@@FETCH_STATUS = -1) -- last fetch  
   BEGIN  
    -- Insert into temp table  
    INSERT INTO #TempPickSlip  
    SELECT ISNULL(RTRIM(Pickheader.Pickheaderkey),''),   
           LOADPLANDETAIL.Loadkey,  
           ORDERS.Orderkey,  
           ISNULL(RTRIM(ORDERS.ExternOrderKey),''),  
           CONVERT(NVARCHAR(255), ORDERS.Notes) AS Notes,  
           ISNULL(RTRIM(ORDERS.ConsigneeKey),''),               
           ISNULL(RTRIM(ORDERS.C_Company),''),  
           ISNULL(RTRIM(ORDERS.c_Address1),''),  
           ISNULL(RTRIM(ORDERS.c_Address2),''),  
           ISNULL(RTRIM(ORDERS.c_Address3),''),  
           ISNULL(RTRIM(ORDERS.c_Address3),'') AS Address4,                              
           ISNULL(RTRIM(ORDERS.c_City),''),     
           ISNULL(RTRIM(ORDERS.c_Zip),''),                     
           ISNULL(RTRIM(SKU.Style),'')+ISNULL(RTRIM(SKU.Color),'') AS StyleColour,   
                   CASE WHEN CHARINDEX(',', ISNULL(RTRIM(SKU.Descr),'')) > 0                      
                THEN SUBSTRING(ISNULL(RTRIM(SKU.Descr),''),1,CHARINDEX(',', ISNULL(RTRIM(SKU.Descr),''))-1)    
                        ELSE ISNULL(RTRIM(SKU.Descr),'')                                              
                        END,                                                                          
           CONVERT(NVARCHAR(255), STORER.Notes1) AS StorerNotes,  
                   Qty = PD.Qty,                              
           LEFT(ISNULL(RTRIM(CODELKUP.Description),''),10) AS UOM,  
           0 AS PACKCaseCnt,  
           ORDERS.deliveryDate,--LOADPLAN.lpuserdefdate01,  
           ORDERS.Storerkey,  
           @c_SkuSize1,  
           @c_SkuSize2,                  
           @c_SkuSize3,  
           @c_SkuSize4,                  
           @c_SkuSize5,                  
           @c_SkuSize6,  
           @c_SkuSize7,                    
           @c_SkuSize8,                  
           @c_SkuSize9,                  
           @c_SkuSize10,  
           @c_SkuSize11,  
           @c_SkuSize12,  
           @c_SkuSize13,  
           @c_SkuSize14,  
           @c_SkuSize15,  
           @c_SkuSize16,  
           @c_SkuSize17,  
           @c_SkuSize18,  
           @c_SkuSize19,  
           @c_SkuSize20,  
           @c_SkuSize21,  
           @c_SkuSize22,  
           @c_SkuSize23,  
           @c_SkuSize24,  
           @c_SkuSize25,  
           @c_SkuSize26,  
           @c_SkuSize27,  
           @c_SkuSize28,  
           @c_SkuSize29,  
           @c_SkuSize30,  
           @c_SkuSize31,  
           @c_SkuSize32,    
        CASE WHEN ISNULL(RTRIM(SKU.Size),'') = @c_SkuSize1 AND ISNULL(RTRIM(SKU.Size),'') <> ''    
             THEN PD.Qty  
             ELSE 0  
             END,  
         CASE WHEN ISNULL(RTRIM(SKU.Size),'') = @c_SkuSize2 AND ISNULL(RTRIM(SKU.Size),'') <> ''  
             THEN PD.Qty  
             ELSE 0  
             END,  
         CASE WHEN ISNULL(RTRIM(SKU.Size),'') = @c_SkuSize3 AND ISNULL(RTRIM(SKU.Size),'') <> ''  
             THEN PD.Qty  
             ELSE 0  
             END,  
         CASE WHEN ISNULL(RTRIM(SKU.Size),'') = @c_SkuSize4 AND ISNULL(RTRIM(SKU.Size),'') <> ''  
             THEN PD.Qty  
             ELSE 0  
             END,  
         CASE WHEN ISNULL(RTRIM(SKU.Size),'') = @c_SkuSize5 AND ISNULL(RTRIM(SKU.Size),'') <> ''  
             THEN PD.Qty  
             ELSE 0  
             END,  
         CASE WHEN ISNULL(RTRIM(SKU.Size),'') = @c_SkuSize6 AND ISNULL(RTRIM(SKU.Size),'') <> ''  
             THEN PD.Qty  
             ELSE 0  
             END,  
         CASE WHEN ISNULL(RTRIM(SKU.Size),'') = @c_SkuSize7 AND ISNULL(RTRIM(SKU.Size),'') <> ''  
             THEN PD.Qty  
             ELSE 0  
             END,  
         CASE WHEN ISNULL(RTRIM(SKU.Size),'') = @c_SkuSize8 AND ISNULL(RTRIM(SKU.Size),'') <> ''  
             THEN PD.Qty  
             ELSE 0  
             END,  
         CASE WHEN ISNULL(RTRIM(SKU.Size),'') = @c_SkuSize9 AND ISNULL(RTRIM(SKU.Size),'') <> ''  
             THEN PD.Qty  
             ELSE 0  
             END,  
         CASE WHEN ISNULL(RTRIM(SKU.Size),'') = @c_SkuSize10 AND ISNULL(RTRIM(SKU.Size),'') <> ''  
             THEN PD.Qty  
             ELSE 0  
             END,  
         CASE WHEN ISNULL(RTRIM(SKU.Size),'') = @c_SkuSize11 AND ISNULL(RTRIM(SKU.Size),'') <> ''  
             THEN PD.Qty  
             ELSE 0  
             END,  
         CASE WHEN ISNULL(RTRIM(SKU.Size),'') = @c_SkuSize12 AND ISNULL(RTRIM(SKU.Size),'') <> ''  
             THEN PD.Qty  
             ELSE 0  
             END,  
         CASE WHEN ISNULL(RTRIM(SKU.Size),'') = @c_SkuSize13 AND ISNULL(RTRIM(SKU.Size),'') <> ''  
             THEN PD.Qty  
             ELSE 0  
             END,  
         CASE WHEN ISNULL(RTRIM(SKU.Size),'') = @c_SkuSize14 AND ISNULL(RTRIM(SKU.Size),'') <> ''  
             THEN PD.Qty   
             ELSE 0  
             END,  
         CASE WHEN ISNULL(RTRIM(SKU.Size),'') = @c_SkuSize15 AND ISNULL(RTRIM(SKU.Size),'') <> ''  
             THEN PD.Qty  
             ELSE 0  
             END,  
         CASE WHEN ISNULL(RTRIM(SKU.Size),'') = @c_SkuSize16 AND ISNULL(RTRIM(SKU.Size),'') <> ''  
             THEN PD.Qty  
             ELSE 0  
             END,  
         CASE WHEN ISNULL(RTRIM(SKU.Size),'') = @c_SkuSize17 AND ISNULL(RTRIM(SKU.Size),'') <> ''  
             THEN PD.Qty  
             ELSE 0  
             END,  
         CASE WHEN ISNULL(RTRIM(SKU.Size),'') = @c_SkuSize18 AND ISNULL(RTRIM(SKU.Size),'') <> ''  
             THEN PD.Qty  
             ELSE 0  
             END,  
         CASE WHEN ISNULL(RTRIM(SKU.Size),'') = @c_SkuSize19 AND ISNULL(RTRIM(SKU.Size),'') <> ''  
             THEN PD.Qty 
             ELSE 0  
             END,  
         CASE WHEN ISNULL(RTRIM(SKU.Size),'') = @c_SkuSize20 AND ISNULL(RTRIM(SKU.Size),'') <> ''  
             THEN PD.Qty  
             ELSE 0  
             END,  
         CASE WHEN ISNULL(RTRIM(SKU.Size),'') = @c_SkuSize21 AND ISNULL(RTRIM(SKU.Size),'') <> ''  
             THEN PD.Qty  
             ELSE 0  
             END,  
         CASE WHEN ISNULL(RTRIM(SKU.Size),'') = @c_SkuSize22 AND ISNULL(RTRIM(SKU.Size),'') <> ''  
             THEN PD.Qty 
             ELSE 0  
             END,  
         CASE WHEN ISNULL(RTRIM(SKU.Size),'') = @c_SkuSize23 AND ISNULL(RTRIM(SKU.Size),'') <> ''  
             THEN PD.Qty   
             ELSE 0  
             END,  
         CASE WHEN ISNULL(RTRIM(SKU.Size),'') = @c_SkuSize24 AND ISNULL(RTRIM(SKU.Size),'') <> ''  
             THEN PD.Qty 
             ELSE 0  
             END,  
         CASE WHEN ISNULL(RTRIM(SKU.Size),'') = @c_SkuSize25 AND ISNULL(RTRIM(SKU.Size),'') <> ''  
             THEN PD.Qty  
             ELSE 0  
             END,  
         CASE WHEN ISNULL(RTRIM(SKU.Size),'') = @c_SkuSize26 AND ISNULL(RTRIM(SKU.Size),'') <> ''  
             THEN PD.Qty 
             ELSE 0  
             END,  
         CASE WHEN ISNULL(RTRIM(SKU.Size),'') = @c_SkuSize27 AND ISNULL(RTRIM(SKU.Size),'') <> ''  
             THEN PD.Qty 
             ELSE 0  
             END,  
         CASE WHEN ISNULL(RTRIM(SKU.Size),'') = @c_SkuSize28 AND ISNULL(RTRIM(SKU.Size),'') <> ''  
             THEN PD.Qty  
             ELSE 0  
             END,  
         CASE WHEN ISNULL(RTRIM(SKU.Size),'') = @c_SkuSize29 AND ISNULL(RTRIM(SKU.Size),'') <> ''  
             THEN PD.Qty  
             ELSE 0  
             END,  
         CASE WHEN ISNULL(RTRIM(SKU.Size),'') = @c_SkuSize30 AND ISNULL(RTRIM(SKU.Size),'') <> ''  
             THEN PD.Qty 
             ELSE 0  
             END,  
         CASE WHEN ISNULL(RTRIM(SKU.Size),'') = @c_SkuSize31 AND ISNULL(RTRIM(SKU.Size),'') <> ''  
             THEN PD.Qty  
             ELSE 0  
             END,  
         CASE WHEN ISNULL(RTRIM(SKU.Size),'') = @c_SkuSize32 AND ISNULL(RTRIM(SKU.Size),'') <> ''  
             THEN PD.Qty  
             ELSE 0  
             END  
 
               ,  CASE WHEN @n_NonPumaExternSO = 1 THEN N'客戶訂單號碼: ' + ISNULL(RTRIM(ORDERS.ExternOrderKey),'') ELSE '' END  
               ,  @n_ShowReportName  
               ,  @n_ShowFullConsignee  
               ,  @n_ShowOrderDate  
               ,  CASE WHEN @n_ShowOrderDate = 1 THEN ORDERS.OrderDate ELSE NULL END   
               , @c_ShowField                       
    FROM ORDERDETAIL OD  WITH (NOLOCK)   
    JOIN ORDERS          WITH (NOLOCK) ON (OD.OrderKey = ORDERS.OrderKey)   
    JOIN PACK            WITH (NOLOCK) ON (OD.Packkey = PACK.Packkey)  
    JOIN LOADPLANDETAIL  WITH (NOLOCK) ON (OD.OrderKey = LOADPLANDETAIL.OrderKey AND   
                                         LOADPLANDETAIL.Loadkey = ORDERS.Loadkey)  
    JOIN LOADPLAN        WITH (NOLOCK) ON (LOADPLANDETAIL.Loadkey = LOADPLAN.Loadkey)                                               
    JOIN SKU             WITH (NOLOCK) ON (SKU.StorerKey = OD.StorerKey AND  
                                           SKU.SKU = OD.SKU)   
    JOIN STORER          WITH (NOLOCK) ON (ORDERS.Storerkey = STORER.Storerkey)                                                          
    LEFT JOIN CODELKUP   WITH (NOLOCK) ON (CODELKUP.Listname = 'PMAUOM' AND OD.UOM = CODELKUP.Code)  
    LEFT JOIN PICKHEADER WITH (NOLOCK) ON (OD.OrderKey = Pickheader.orderkey)  
    --CS03 S
    LEFT JOIN dbo.PackHeader PH WITH (NOLOCK) ON PH.OrderKey = ORDERS.Orderkey
    CROSS APPLY( SELECT PD.PickSlipNo,SUM(PD.qty) AS QTY 
                 FROM PACKDETAIL PD WITH (NOLOCK) Where PD.PickSlipNo = PH.PickSlipNo AND PD.StorerKey = OD.StorerKey AND PD.SKU = OD.Sku
                 GROUP BY PD.PickSlipNo) AS PD
    --CS03 E
    WHERE ORDERS.OrderKey = @c_PrevOrderKey   
            AND   SKU.Style = @c_PrevStyle                                                             
            AND   SKU.Color = @c_PrevColor                                                            
   
    GROUP BY ISNULL(RTRIM(Pickheader.Pickheaderkey),''),                      
             LOADPLANDETAIL.Loadkey,                                          
             ORDERS.Orderkey,                                                 
             ISNULL(RTRIM(ORDERS.ExternOrderKey),''),                         
             CONVERT(NVARCHAR(255), ORDERS.Notes),                   
             ISNULL(RTRIM(ORDERS.ConsigneeKey),''),                           
             ISNULL(RTRIM(ORDERS.C_Company),''),                              
             ISNULL(RTRIM(ORDERS.c_Address1),''),                             
             ISNULL(RTRIM(ORDERS.c_Address2),''),                             
             ISNULL(RTRIM(ORDERS.c_Address3),''),  
             ISNULL(RTRIM(ORDERS.c_Address3),''),                                     
             ISNULL(RTRIM(ORDERS.c_City),''),                                 
             ISNULL(RTRIM(ORDERS.c_Zip),''),                                                                    
             ISNULL(RTRIM(SKU.Style),'')+ISNULL(RTRIM(SKU.Color),''),            
             CASE WHEN CHARINDEX(',', ISNULL(RTRIM(SKU.Descr),'')) > 0                      
                  THEN SUBSTRING(ISNULL(RTRIM(SKU.Descr),''),1,CHARINDEX(',', ISNULL(RTRIM(SKU.Descr),''))-1)  
                          ELSE ISNULL(RTRIM(SKU.Descr),'')                                        
                          END,                                                                                                
             CONVERT(NVARCHAR(255), STORER.Notes1),  
             LEFT(ISNULL(RTRIM(CODELKUP.Description),''),10),  
             ORDERS.deliveryDate,--LOADPLAN.lpuserdefdate01,       
             ORDERS.Storerkey,                 
             ISNULL(RTRIM(SKU.Size),'')  
                  ,  CASE WHEN @n_ShowOrderDate = 1 THEN ORDERS.OrderDate ELSE NULL END               
                  ,  SKU.Style,SKU.color  ,(PD.qty)
    HAVING (PD.qty) > 0  
    ORDER BY ORDERS.OrderKey,  
             StyleColour,  
             UOM  
      
    -- Reset counter and skusize  
    SELECT @n_Count = 0  
    SELECT @c_SkuSize1='',  @c_SkuSize2='',  @c_SkuSize3='',  @c_SkuSize4=''  
    SELECT @c_SkuSize5='',  @c_SkuSize6='',  @c_SkuSize7='',  @c_SkuSize8=''  
    SELECT @c_SkuSize9='',  @c_SkuSize10='', @c_SkuSize11='', @c_SkuSize12=''  
    SELECT @c_SkuSize13='', @c_SkuSize14='', @c_SkuSize15='', @c_SkuSize16=''  
    SELECT @c_SkuSize17='', @c_SkuSize18='', @c_SkuSize19='', @c_SkuSize20=''  
    SELECT @c_SkuSize21='', @c_SkuSize22='', @c_SkuSize23='', @c_SkuSize24=''  
    SELECT @c_SkuSize25='', @c_SkuSize26='', @c_SkuSize27='', @c_SkuSize28=''  
    SELECT @c_SkuSize29='', @c_SkuSize30='', @c_SkuSize31='', @c_SkuSize32=''            
   END  
      END -- WHILE (@@FETCH_STATUS <> -1)  
  
      CLOSE pick_cur  
      DEALLOCATE pick_cur  
   END -- WHILE (1=1)  
  
 
   SELECT DISTINCT OD.Orderkey, MIN(ISNULL(OD.Userdefine04,'')) AS Userdefine04  
   ,ISNULL(RTRIM(SKU.Style),'')+ISNULL(RTRIM(SKU.Color),'') as sku_stylecolor  
   INTO #TempOD  
   FROM ORDERS O (NOLOCK)  
   JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey  
   LEFT JOIN PICKDETAIL WITH (NOLOCK) ON (PICKDETAIL.Orderkey = O.Orderkey AND PICKDETAIL.SKU=OD.SKU AND PICKDETAIL.Orderlinenumber = OD.Orderlinenumber)     
   JOIN SKU SKU WITH (NOLOCK) ON SKU.SKU = PICKDETAIL.SKU    
   WHERE O.Loadkey = @c_LoadKey  
   GROUP BY OD.Orderkey
           ,sku.style,sku.color    
declare @dt_orderdate Datetime  
 

   SELECT T.PickSlipNo, T.Loadkey, T.OrderKey, T.ExternOrderKey, T.Notes,   
          CASE WHEN ShowFullConsignee = 1 THEN T.ConsigneeKey ELSE SUBSTRING(T.ConsigneeKey,4,12) END Consigneekey,  
          T.Company, T.c_Address1, T.c_Address2, T.c_Address3, T.c_Address4, T.c_City, T.c_Zip,        
          T.StyleColor, T.SkuDescr, T.Storernotes, Qty=SUM(T.Qty), T.UOM, T.CaseCnt, T.lpuserdefdate01, T.Storerkey, 
          T.SkuSize1,  T.SkuSize2,  T.SkuSize3,  T.SkuSize4,  T.SkuSize5,  T.SkuSize6,  T.SkuSize7,  T.SkuSize8,   
          T.SkuSize9,  T.SkuSize10, T.SkuSize11, T.SkuSize12, T.SkuSize13, T.SkuSize14, T.SkuSize15, T.SkuSize16,  
          T.SkuSize17, T.SkuSize18, T.SkuSize19, T.SkuSize20, T.SkuSize21, T.SkuSize22, T.SkuSize23, T.SkuSize24,   
          T.SkuSize25, T.SkuSize26, T.SkuSize27, T.SkuSize28, T.SkuSize29, T.SkuSize30, T.SkuSize31, T.SkuSize32,  
          SUM(T.Qty1) Qty1, SUM(T.Qty2) Qty2, SUM(T.Qty3) Qty3, SUM(T.Qty4) Qty4, SUM(T.Qty5) Qty5, SUM(T.Qty6) Qty6,   
          SUM(T.Qty7) Qty7, SUM(T.Qty8) Qty8, SUM(T.Qty9) Qty9, SUM(T.Qty10) Qty10, SUM(T.Qty11) Qty11, SUM(T.Qty12) Qty12,   
          SUM(T.Qty13) Qty13, SUM(T.Qty14) Qty14, SUM(T.Qty15) Qty15, SUM(T.Qty16) Qty16,  
          SUM(T.Qty17) Qty17, SUM(T.Qty18) Qty18, SUM(T.Qty19) Qty19, SUM(T.Qty20) Qty20, SUM(T.Qty21) Qty21, SUM(T.Qty22) Qty22,   
          SUM(T.Qty23) Qty23, SUM(T.Qty24) Qty24, SUM(T.Qty25) Qty25, SUM(T.Qty26) Qty26, SUM(T.Qty27) Qty27, SUM(T.Qty28) Qty28,   
          SUM(T.Qty29) Qty29, SUM(T.Qty30) Qty30, SUM(T.Qty31) Qty31, SUM(T.Qty32) Qty32,  
          ISNULL(STORER.Consigneefor,'') Consigneefor, #TempOD.Userdefine04                                          
         , T.NonPumaExternSO                                                                                            
         , T.ShowReportName                                                                                             
         , T.ShowOrderDate                                                                                              
         , T.OrderDate                                                                                                                   
         , T.ShowField                                                                                                              
   FROM #TempPickSlip T  
   LEFT JOIN STORER (NOLOCK) ON T.Consigneekey = STORER.Storerkey AND STORER.Type = '2'  
   LEFT JOIN #TempOD (NOLOCK) ON T.Orderkey = #TempOD.Orderkey AND T.Stylecolor=#TempOd.sku_stylecolor  
   GROUP BY T.PickSlipNo, T.Loadkey, T.OrderKey, T.ExternOrderKey, T.Notes,   
            CASE WHEN ShowFullConsignee = 1 THEN T.ConsigneeKey ELSE SUBSTRING(T.ConsigneeKey,4,12) END, 
            T.Company, T.c_Address1, T.c_Address2, T.c_Address3, T.c_Address4, T.c_City, T.c_Zip,     
            T.StyleColor, T.SkuDescr, T.Storernotes, T.UOM, T.CaseCnt, T.lpuserdefdate01, T.Storerkey,            
            T.SkuSize1, T.SkuSize2, T.SkuSize3, T.SkuSize4, T.SkuSize5, T.SkuSize6, T.SkuSize7, T.SkuSize8,   
            T.SkuSize9, T.SkuSize10, T.SkuSize11, T.SkuSize12, T.SkuSize13, T.SkuSize14, T.SkuSize15, T.SkuSize16,  
            T.SkuSize17, T.SkuSize18, T.SkuSize19, T.SkuSize20, T.SkuSize21, T.SkuSize22, T.SkuSize23, T.SkuSize24,   
            T.SkuSize25, T.SkuSize26, T.SkuSize27, T.SkuSize28, T.SkuSize29, T.SkuSize30, T.SkuSize31, T.SkuSize32,  
            ISNULL(STORER.Consigneefor,''), #TempOD.Userdefine04                                                   
         , T.NonPumaExternSO                                                                                            
         , T.ShowReportName                                                                                             
         , T.ShowOrderDate                                                                                              
         , T.OrderDate                                                                                                             
         , T.ShowField      

   DROP TABLE #TempOrder  
   DROP TABLE #TempPickSlip  
   DROP TABLE #TempOD  

QUIT_SP:
                                                                           

END  
  

GO