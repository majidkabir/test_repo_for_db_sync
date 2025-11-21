SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_RPT_TH_WAV_CZ_FCST                                  */
/* Creation Date: 2022-05-09                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: Report - LIT will create LOGIREPORT                         */
/*        : WMS-19659 - TH - Create Forecast SP for adidas              */
/*          CartonizationV1.0                                           */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2022-05-09  Wan      1.0   Created.                                  */
/* 2022-05-09  Wan      1.0   DevOps Combine Script.                    */
/* 2022-05-13  Wan01    1.1   Fixed Linking Issue                       */
/************************************************************************/
CREATE PROC [dbo].[isp_RPT_TH_WAV_CZ_FCST]
   @c_Storerkey   NVARCHAR(15) 
,  @c_Wavekey     NVARCHAR(10) = ''   
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt          INT         = 0
         , @n_Continue           INT         = 1
         , @n_Found              INT         = 0
         
         , @b_Success            INT         = 1
         , @n_Err                INT         = 0
         , @c_ErrMsg             NVARCHAR(255)= ''
         , @n_debug              INT         = 0
         
         , @n_RowRef             INT         = 0
         , @n_RowRef_FC          INT         = 0     
         , @n_Status             INT         = 0      --0:Original, 1:Split, 2:New
   
         , @c_Release_Opt5       NVARCHAR(4000) = ''  

         , @c_Facility           NVARCHAR(5) = '' 
         , @n_PackAccessQty      INT         = 1 

         , @c_Loadkey            NVARCHAR(10)= ''
         , @c_Orderkey           NVARCHAR(10)= ''
         , @c_Consigneekey       NVARCHAR(15)= ''
         , @c_Route              NVARCHAR(10)= ''
         , @c_ExternOrderkey     NVARCHAR(30)= ''
         , @c_DocType            NVARCHAR(10)= ''

         , @c_PickZone           NVARCHAR(10) = ''
         , @c_SkuGroup           NVARCHAR(10) = ''
         , @c_PackZone           NVARCHAR(10) = ''   
         , @c_Style              NVARCHAR(10) = ''
         , @c_Color              NVARCHAR(10) = ''   
         , @c_Size               NVARCHAR(10) = ''
         , @n_RecCnt             NVARCHAR(20) = ''       
         
         , @n_SplitToAccessQty   INT         = 0         

         , @n_CartonSeqNo        INT         = 0
         , @c_CartonGroup_B2B    NVARCHAR(10)= ''
         , @c_CartonGroup_B2C    NVARCHAR(10)= ''
         , @c_CartonType_B2B     NVARCHAR(10)= ''
         , @c_CartonType_B2B_w   NVARCHAR(10)= ''
         , @c_CartonType_B2B_New NVARCHAR(10)= ''
         , @c_CartonType_B2C     NVARCHAR(10)= ''
         , @n_MaxCube_B2B        FLOAT       = 0.00
         , @n_MaxCube_B2B_w      FLOAT       = 0.00
         , @n_MaxCube_B2B_New    FLOAT       = 0.00
         , @n_MaxCube_B2C        FLOAT       = 0.00
         , @n_MaxWeight_B2B      FLOAT       = 0.00
         , @n_MaxWeight_B2B_w    FLOAT       = 0.00         
         , @n_MaxWeight_B2C      FLOAT       = 0.00
         
         , @n_RemainingCube      FLOAT       = 0.00
                
         , @c_IsCompletePack     NVARCHAR(5) = ''
         , @c_Sku_Optimize       NVARCHAR(20)= ''
         , @c_Sku_ToPack         NVARCHAR(20)= ''
         , @n_Qty_Optimize       INT         = 0
         , @n_Qty_ToPack         INT         = 0  
         , @n_Qty_ToUpd          INT         = 0  
         , @n_OrignalQty_ToPack  INT         = 0 
         , @n_QtyRemain_ToPack   INT         = 0          
         , @n_ID_ToPack          INT         = 0
         , @n_ID_ToUpd           INT         = 0  
         , @n_TotalToPack        INT         = 0         
                                                        
         , @n_SkuQty_ToPack      INT         = 0         
         , @n_SkuOrigQty_ToPack  INT         = 0         
         , @n_SkuItemToPackCnt   INT         = 0         
         , @n_Qty_ToDel          INT         = 0         
         
         , @b_RemoveLastRecord   INT         = 0         
                  
         , @b_MinQty1ToPack      BIT         = 0
         
         , @n_ItemToPackCnt      INT         = 0 
         , @b_SplitPickdetail    INT         = 0

         , @c_PickDetailKey      NVARCHAR(10)= ''
         --, @c_Storerkey          NVARCHAR(15)= ''
         , @c_Sku                NVARCHAR(20)= ''
         , @c_UOM                NVARCHAR(10)= ''
         , @c_DropID             NVARCHAR(20)= ''   
         , @n_PickItemCube       FLOAT       = 0.00
         , @n_PickItemWgt        FLOAT       = 0.00
         , @n_StdCube            FLOAT       = 0.00
         , @n_StdGrossWgt        FLOAT       = 0.00
         , @n_PackQtyIndicator   INT         = 0    
         , @n_QtyToPackBundle    INT         = 0    
         , @n_Qty                INT         = 0

         , @n_CartonNo           INT         = 0
         , @c_PickSlipNo         NVARCHAR(10)= ''
         , @c_LabelNo            NVARCHAR(20)= ''
         , @c_NewPickDetailKey   NVARCHAR(10)= '' 
         
         , @CUR_B2C_CZ           CURSOR
         , @CUR_B2B_CZ           CURSOR
         , @CUR_ORD              CURSOR
         , @CUR_PD               CURSOR
         
         , @CUR_WV               CURSOR
 
   DECLARE @t_ORDERS             TABLE
         (  Wavekey              NVARCHAR(10) NOT NULL   DEFAULT('') 
         ,  Loadkey              NVARCHAR(10) NOT NULL   DEFAULT('') 
         ,  Orderkey             NVARCHAR(10) NOT NULL   DEFAULT('')    PRIMARY KEY
         ,  Facility             NVARCHAR(5)  NOT NULL   DEFAULT('')
         ,  Storerkey            NVARCHAR(15) NOT NULL   DEFAULT('')
         ,  [Route]              NVARCHAR(10) NOT NULL   DEFAULT('')
         ,  ExternOrderkey       NVARCHAR(50) NOT NULL   DEFAULT('') 
         ,  DocType              NVARCHAR(10) NOT NULL   DEFAULT('') 
         ,  Ecom_Single_Flag     NVARCHAR(10) NOT NULL   DEFAULT('')
         )

   DECLARE @t_SkuGroup           TABLE
         (  RowRef               INT      IDENTITY(1,1)                 PRIMARY KEY
         ,  ListName             NVARCHAR(10) NOT NULL   DEFAULT('') 
         ,  Code                 NVARCHAR(30) NOT NULL   DEFAULT('') 
         ,  Storerkey            NVARCHAR(15) NOT NULL   DEFAULT('')  
         ,  UDF01                NVARCHAR(60) NOT NULL   DEFAULT('')     
         ,  UDF02                NVARCHAR(60) NOT NULL   DEFAULT('')                   
         )  

    
   DECLARE @t_OptimizeCZGroup_FC TABLE
         (  RowRef               INT            IDENTITY(1,1) PRIMARY KEY
         ,  CartonizationGroup   NVARCHAR(10)   NOT NULL DEFAULT ('')
         ,  CartonType           NVARCHAR(10)   NOT NULL DEFAULT ('')
         ,  [Cube]               FLOAT          NOT NULL DEFAULT (0.00)
         ,  MaxWeight            FLOAT          NOT NULL DEFAULT (0.00)
         ,  CartonLength         FLOAT          NOT NULL DEFAULT (0.00)
         ,  CartonWidth          FLOAT          NOT NULL DEFAULT (0.00)
         ,  CartonHeight         FLOAT          NOT NULL DEFAULT (0.00)
         )
         
   DECLARE @t_OptimizeResult     TABLE
         (  ContainerID          NVARCHAR(10)   NULL  DEFAULT('')    
         ,  AlgorithmID          NVARCHAR(10)   NULL  DEFAULT('')  
         ,  IsCompletePack       NVARCHAR(10)   NULL  DEFAULT('')  
         ,  ID                   INT            NULL  DEFAULT('')  
         ,  SKU                  NVARCHAR(20)   NULL  DEFAULT('')  
         ,  Qty                  INT            NULL  DEFAULT(0)  
         )    

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''
  
   IF OBJECT_ID('tempdb..#PICKDETAIL_WIP','U') IS NOT NULL
   BEGIN
      DROP TABLE #PICKDETAIL_WIP;
   END
   
   CREATE TABLE #PICKDETAIL_WIP  
   (  RowRef            INT          IDENTITY(1,1)     PRIMARY KEY
   ,  Orderkey          NVARCHAR(10) DEFAULT('')
   ,  Pickdetailkey     NVARCHAR(10) DEFAULT('')   
   ,  Storerkey         NVARCHAR(15) DEFAULT('')
   ,  Sku               NVARCHAR(20) DEFAULT('')
   ,  UOM               NVARCHAR(10) DEFAULT('')
   ,  UOMQty            INT          DEFAULT(0)
   ,  Qty               INT          DEFAULT(0)
   ,  Lot               NVARCHAR(10) DEFAULT('')
   ,  Loc               NVARCHAR(10) DEFAULT('')          
   ,  DropID            NVARCHAR(20) DEFAULT('')
   ,  PickLoc           NVARCHAR(10) DEFAULT('')         
   ,  PickZone          NVARCHAR(10) DEFAULT('')
   ,  PickLogicalloc    NVARCHAR(10) DEFAULT('')
   ,  PackZone          NVARCHAR(10) DEFAULT('')         --Ecom PackZone, Single = PackStation, Multi = SortStation Group 
   ,  PackStation       INT          DEFAULT(0)
   ,  PickItemCube      FLOAT        DEFAULT(0.00)
   ,  PickItemWgt       FLOAT        DEFAULT(0.00)
   ,  SkuGroup          NVARCHAR(30) DEFAULT('')         
   ,  Style             NVARCHAR(10) DEFAULT('')        
   ,  Color             NVARCHAR(10) DEFAULT('')      
   ,  Size              NVARCHAR(10) DEFAULT('')  
   ,  PackQtyIndicator  INT          DEFAULT(0) 
   ,  StdCube           FLOAT        DEFAULT(0.00)
   ,  StdGrossWgt       FLOAT        DEFAULT(0.00)
   ,  [Length]          FLOAT        DEFAULT(0.00)    
   ,  Width             FLOAT        DEFAULT(0.00)    
   ,  Height            FLOAT        DEFAULT(0.00)    
   ,  PickSlipNo        NVARCHAR(10) DEFAULT('')
   ,  LabelNo           NVARCHAR(20) DEFAULT('')
   ,  CartonGroup       NVARCHAR(10) DEFAULT('')           
   ,  CartonType        NVARCHAR(10) DEFAULT('')
   ,  CartonSeqNo       INT          DEFAULT(0)
   ,  CartonCube        FLOAT        DEFAULT(0.00)
   ,  Status_CZ         INT          DEFAULT(0)  
   ,  PackAccessQty     NVARCHAR(10) DEFAULT('') 
   ,  SplitToAccessQty  INT          DEFAULT(0)                 
   )
   

   IF OBJECT_ID('tempdb..#OptimizeCZGroup','U') IS NOT NULL
   BEGIN
      DROP TABLE #OptimizeCZGroup;
   END
   
   CREATE TABLE #OptimizeCZGroup
   (  RowRef               INT            IDENTITY(1,1) PRIMARY KEY
   ,  CartonizationGroup   NVARCHAR(10)   NOT NULL DEFAULT ('')
   ,  CartonType           NVARCHAR(10)   NOT NULL DEFAULT ('')
   ,  [Cube]               FLOAT          NOT NULL DEFAULT (0.00)
   ,  MaxWeight            FLOAT          NOT NULL DEFAULT (0.00)
   ,  CartonLength         FLOAT          NOT NULL DEFAULT (0.00)
   ,  CartonWidth          FLOAT          NOT NULL DEFAULT (0.00)
   ,  CartonHeight         FLOAT          NOT NULL DEFAULT (0.00)
   )


   IF OBJECT_ID('tempdb..#OptimizeItemToPack','U') IS NOT NULL
   BEGIN
      DROP TABLE #OptimizeItemToPack;
   END
   
   CREATE TABLE #OptimizeItemToPack 
      (
         ID          INT                     IDENTITY(1,1)  PRIMARY KEY
      ,  Storerkey   NVARCHAR(15)   NOT NULL DEFAULT('') 
      ,  SKU         NVARCHAR(20)   NOT NULL DEFAULT('')
      ,  Dim1        DECIMAL(10,6)  NOT NULL DEFAULT(0.00)
      ,  Dim2        DECIMAL(10,6)  NOT NULL DEFAULT(0.00)
      ,  Dim3        DECIMAL(10,6)  NOT NULL DEFAULT(0.00)
      ,  Quantity    INT            NOT NULL DEFAULT(0)
      ,  RowRef      INT            NOT NULL DEFAULT(0)
      ,  OriginalQty INT            NOT NULL DEFAULT(0)
      ,  StdGrossWgt FLOAT          NOT NULL DEFAULT(0.00)         
      ,  SortID      INT            NOT NULL DEFAULT(0)         
      )
   
   IF OBJECT_ID('tempdb..#ItemToPackBySku','U') IS NOT NULL
   BEGIN
      DROP TABLE #ItemToPackBySku;
   END
   
   CREATE TABLE #ItemToPackBySku 
      (
         ID          INT            NOT NULL DEFAULT(0)  PRIMARY KEY
      ,  RowRef      INT            NOT NULL DEFAULT(0)
      ,  Storerkey   NVARCHAR(15)   NOT NULL DEFAULT('') 
      ,  SKU         NVARCHAR(20)   NOT NULL DEFAULT('')
      ,  Quantity    INT            NOT NULL DEFAULT(0)
      ,  OriginalQty INT            NOT NULL DEFAULT(0)
      )

   IF OBJECT_ID('tempdb..#RPTCZFCST','U') IS NOT NULL
   BEGIN
      DROP TABLE #RPTCZFCST
   END
   
   CREATE TABLE #RPTCZFCST 
      (  RowRef            INT          IDENTITY(1,1)     PRIMARY KEY
      ,  WaveKey           NVARCHAR(10) DEFAULT('')
      ,  Loadkey           NVARCHAR(10) DEFAULT('')
      ,  Orderkey          NVARCHAR(10) DEFAULT('')
      ,  ExternOrderkey    NVARCHAR(50) DEFAULT('')   
      ,  TotalCarton       INT          DEFAULT(0)
      ,  ErrMsg            NVARCHAR(255)DEFAULT('')
      )
      
   WHILE @@TRANCOUNT > 0 
   BEGIN
      COMMIT TRAN
   END  
   SET @c_Wavekey = ISNULL(@c_Wavekey,'')
   IF @c_Wavekey = ''
   BEGIN
      SET @CUR_WV = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT w.WaveKey
      FROM dbo.WAVE AS w WITH (NOLOCK)
      JOIN dbo.ORDERS AS o WITH (NOLOCK) ON o.UserDefine09 = w.Wavekey     --(Wan01)
      WHERE o.StorerKey = @c_Storerkey
      AND w.TMReleaseFlag = 'N'
      AND w.Descr NOT IN ('BYPASSCZFCST')
      GROUP BY w.WaveKey
      ORDER BY w.Wavekey
   END
   ELSE
   BEGIN
      SET @CUR_WV = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT w.WaveKey
      FROM dbo.WAVE AS w WITH (NOLOCK)
      JOIN dbo.ORDERS AS o WITH (NOLOCK) ON o.UserDefine09 = w.Wavekey     --(Wan01)
      WHERE o.StorerKey = @c_Storerkey
      AND w.WaveKey = @c_Wavekey
      AND w.TMReleaseFlag = 'N'
      AND w.Descr NOT IN ('BYPASSCZFCST')
      GROUP BY w.WaveKey
      ORDER BY w.Wavekey
   END
   OPEN @CUR_WV
   
   FETCH NEXT FROM @CUR_WV INTO @c_Wavekey
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @n_Continue = 1

      TRUNCATE TABLE #PICKDETAIL_WIP;
      TRUNCATE TABLE #ItemToPackBySku;
      TRUNCATE TABLE #OptimizeCZGroup;
      TRUNCATE TABLE #OptimizeItemToPack;
      
      DELETE FROM @t_ORDERS;
      DELETE FROM @t_OptimizeCZGroup_FC;
      DELETE FROM @t_OptimizeResult;
      DELETE FROM @t_SkuGroup
      
      SELECT TOP 1 @c_Sku = RTRIM(p.Sku)    
                  ,@n_Found =  CASE WHEN s.[Length] = 0.00 THEN 1  
                                    WHEN s.Width = 0.00 THEN 1  
                                    WHEN s.Height = 0.00 THEN 1  
                                    WHEN s.STDCUBE = 0.00 THEN 1  
                                    WHEN s.STDGROSSWGT = 0.00 THEN 1    
                                    WHEN CONVERT(DECIMAL(12,5),s.[Length] * s.Width * s.Height) - CONVERT(DECIMAL(12,5),s.STDCUBE) NOT BETWEEN -0.00001 AND 0.00001 THEN 1  
                                    ELSE 0   
                                    END   
      FROM dbo.WAVEDETAIL AS w (NOLOCK)    
      JOIN dbo.ORDERDETAIL AS p (NOLOCK) ON p.Orderkey = w.Orderkey    
      JOIN dbo.SKU AS s (NOLOCK) ON s.StorerKey = p.Storerkey AND s.Sku = p.Sku  
      WHERE w.Wavekey = @c_Wavekey     
      ORDER BY 2 DESC  
   
      IF @n_Found = 1  
      BEGIN    
         SET @n_Continue = 3    
         SET @n_Err = 64001    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Found Sku Length, Width, Height, StdCube, StdGrossWgt not setup OR LxWxH <> StdCube. Sku:' + @c_Sku  
                      +'. (isp_RPT_TH_WAV_CZ_FCST)'    
         GOTO NEXT_WAVE    
      END  
   
      SET @n_Found = 0  
      SET @c_Sku = ''  
      SELECT TOP 1 @c_Sku = RTRIM(p.Sku)   
                  ,@n_Found =  CASE WHEN C.ListName IS NULL THEN 1  
                                    WHEN c.UDF01 = '' THEN 1  
                                    WHEN c2.CartonizationKey IS NULL THEN 1  
                               ELSE 0   
                                    END  
      FROM dbo.WAVEDETAIL AS w (NOLOCK)    
      JOIN dbo.ORDERDETAIL AS p (NOLOCK) ON p.Orderkey = w.Orderkey    
      JOIN dbo.SKU AS s (NOLOCK) ON s.StorerKey = p.Storerkey AND s.Sku = p.Sku  
      LEFT JOIN dbo.CODELKUP AS c WITH (NOLOCK) ON  c.LISTNAME = 'SKUGROUP'   
                                                AND C.Code = s.SkuGroup  
                                                AND c.Storerkey = p.Storerkey  
      LEFT JOIN dbo.CARTONIZATION AS c2 WITH (NOLOCK) ON c.UDF01 = c2.CartonizationGroup  
      WHERE w.Wavekey = @c_Wavekey   
      ORDER BY 2 DESC  
     
      IF @n_Found = 1  
      BEGIN    
         SET @n_Continue = 3    
         SET @n_Err = 64002   
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': SkuGroup/CartonGroup Not Found in Codelkup - SkuGroup/Cartonization. Sku: ' + @c_Sku  
                      + '. (isp_RPT_TH_WAV_CZ_FCST)'    
         GOTO NEXT_WAVE    
      END    

      INSERT INTO @t_ORDERS
           ( Wavekey, Loadkey, Orderkey, Facility, Storerkey, [Route], ExternOrderkey, DocType, Ecom_Single_Flag )
      SELECT WD.Wavekey, OH.Loadkey, OH.Orderkey, OH.Facility, OH.Storerkey, OH.[Route], OH.ExternOrderkey, OH.DocType, OH.ECOM_SINGLE_Flag
      FROM WAVEDETAIL WD WITH (NOLOCK)
      JOIN ORDERS OH WITH (NOLOCK) ON WD.Orderkey = OH.Orderkey
      AND OH.[Status] = '0'
      WHERE WD.Wavekey = @c_Wavekey
  
   
      IF @@ROWCOUNT = 0 
      BEGIN
         GOTO NEXT_WAVE
      END
   
      SELECT TOP 1 
               @c_Facility = tor.Facility
             , @c_Storerkey = tor.Storerkey
      FROM @t_ORDERS AS tor

      EXEC nspGetRight          
            @c_Facility  = @c_Facility          
         ,  @c_StorerKey = @c_StorerKey         
         ,  @c_sku       = NULL          
         ,  @c_ConfigKey = 'ReleaseWave_SP'         
         ,  @b_Success   = @b_Success        OUTPUT          
         ,  @c_authority = ''           
         ,  @n_err       = @n_err            OUTPUT          
         ,  @c_errmsg    = @c_errmsg         OUTPUT   
         ,  @c_OPtion5   = @c_Release_Opt5   OUTPUT 
       
      IF @b_Success = 0
      BEGIN
         SET @n_Continue = 3
         GOTO NEXT_WAVE
      END
   
      SET @c_CartonGroup_B2C = ''
      SELECT @c_CartonGroup_B2C = dbo.fnc_GetParamValueFromString('@c_CartonGroup_B2C', @c_Release_Opt5, @c_CartonGroup_B2C) 
      
      SELECT @c_CartonType_B2C  = c.CartonType
            ,@n_MaxCube_B2C     = c.[Cube]
      FROM dbo.CARTONIZATION AS c WITH (NOLOCK) 
      WHERE c.CartonizationGroup = @c_CartonGroup_B2C   
      
      SELECT @c_CartonGroup_B2B = s.CartonGroup
      FROM STORER AS s WITH (NOLOCK)
      WHERE s.Storerkey = @c_Storerkey
       
      INSERT INTO #PICKDETAIL_WIP  
         (  
            Orderkey          
         ,  Pickdetailkey     
         ,  Storerkey         
         ,  Sku               
         ,  UOM               
         ,  UOMQty            
         ,  Qty               
         ,  Lot               
         ,  Loc
         ,  DropID 
         ,  PickLoc
         ,  PickItemCube          
         ,  PickItemWgt           
         ,  SkuGroup          
         ,  Style             
         ,  Color             
         ,  Size              
         ,  PackQtyIndicator  
         ,  StdCube           
         ,  StdGrossWgt       
         ,  [Length]          
         ,  Width             
         ,  Height 
         ,  CartonGroup
         ,  PackAccessQty           
         )        
      
      SELECT
            p.Orderkey          
         ,  p.OrderLineNumber     
         ,  p.Storerkey         
         ,  p.Sku               
         ,  UOM = '7'              
         ,  p.OpenQty            
         ,  p.OpenQty               
         ,  Lot        = ''
         ,  Loc        = ''
         ,  DropID     = ''         
         ,  PickLoc    = '' 
         ,  PickItemCube = p.OpenQty * s2.stdcube       
         ,  PickItemWgt  = p.OpenQty * s2.stdgrosswgt        
         ,  s2.SkuGroup          
         ,  s2.Style             
         ,  s2.Color             
         ,  s2.Size              
         ,  PackQtyIndicator = CASE WHEN ISNULL(s2.PackQtyIndicator,1) = 0 THEN 1 ELSE ISNULL(s2.PackQtyIndicator,1) END
         ,  s2.StdCube           
         ,  s2.StdGrossWgt    
         ,  [Length]= ISNULL(s2.[Length],0.00)    
         ,  Width   = ISNULL(s2.Width,0.00)    
         ,  Height  = ISNULL(s2.Height,0.00) 
         ,  CartonGroup   = ISNULL(c.UDF01,'')   
         ,  PackAccessQty = '0'         
      FROM @t_ORDERS AS tor  
      JOIN dbo.ORDERDETAIL AS p WITH (NOLOCK) ON p.Orderkey = tor.Orderkey  
      JOIN dbo.SKU AS s2 WITH (NOLOCK) ON s2.StorerKey = p.Storerkey AND s2.Sku = p.Sku
      JOIN dbo.CODELKUP AS c WITH (NOLOCK) ON  c.LISTNAME = 'SkuGroup'
                                           AND c.Code = s2.SkuGroup
                                           AND c.Storerkey = p.Storerkey
      ORDER BY p.OrderKey 
        
      UPDATE pw  
           SET pw.PackZone = ''   
            ,  pw.PackStation  = 0                                                            
            ,  pw.PickItemCube =  (pw.Qty / (1.00 * pw.PackQtyIndicator)) * pw.StdCube
 
            ,  pw.PickItemWgt  =  (pw.Qty / (1.00 * pw.PackQtyIndicator)) * pw.StdGrossWgt
                         
            ,  pw.[Length]=  pw.[Length] / (1.00 * pw.PackQtyIndicator)  
                            
            ,  pw.Width   =  pw.Width    / (1.00 * pw.PackQtyIndicator) 
                           
            ,  pw.Height  =  pw.Height   / (1.00 * pw.PackQtyIndicator) 
                                                                                                                                                                            
      FROM @t_ORDERS AS tor          
      JOIN #PICKDETAIL_WIP AS pw ON pw.Orderkey = tor.Orderkey

      INSERT INTO #OptimizeCZGroup
         (  CartonizationGroup  
         ,  CartonType          
         ,  [Cube]              
         ,  MaxWeight  
         ,  CartonLength                              
         ,  CartonWidth                               
         ,  CartonHeight                                     
         )
      SELECT 
            c.CartonizationGroup  
         ,  c.CartonType          
         ,  c.[Cube]              
         ,  c.MaxWeight 
         ,  CartonLength = ISNULL(c.CartonLength,0.00)  
         ,  CartonWidth  = ISNULL(c.CartonWidth,0.00)   
         ,  CartonHeight = ISNULL(c.CartonHeight,0.00)  
      FROM #PICKDETAIL_WIP AS pw           
      JOIN dbo.CARTONIZATION AS c WITH (NOLOCK) ON c.CartonizationGroup = pw.CartonGroup
      GROUP BY c.CartonizationGroup  
            ,  c.CartonType          
            ,  c.[Cube]              
            ,  c.MaxWeight 
            ,  ISNULL(c.CartonLength,0.00)  
            ,  ISNULL(c.CartonWidth,0.00)   
            ,  ISNULL(c.CartonHeight,0.00) 
      ORDER BY c.CartonizationGroup
              ,c.[Cube]
              ,c.MaxWeight
           
      --------------------------------------------------------
      -- 2) For DP/DPP - Cartonization UOM IN ('6','7')
      -- By Mezzanine, Division, SortStationGroup/PackStation
      -- Sort By Style, Color, Size
      --------------------------------------------------------  
      SET @n_CartonSeqNo = 0
      SELECT TOP 1 @n_CartonSeqNo = pw.CartonSeqNo
      FROM #PICKDETAIL_WIP AS pw
      ORDER BY pw.CartonSeqNo DESC
   
      SET @CUR_B2C_CZ = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT pw.PickZone   -- Mezzanine
            ,pw.SkuGroup   -- Division
            ,pw.PackZone   -- SortStationGroup / PackStation
      FROM @t_ORDERS AS tor        
      JOIN #PICKDETAIL_WIP AS pw ON pw.Orderkey = tor.Orderkey    
      WHERE tor.DocType = 'E'   
      AND pw.UOM IN ('6', '7')
      AND pw.CartonType = ''
      GROUP BY pw.PickZone   
            ,  pw.SkuGroup   
            ,  pw.PackZone   
   
      OPEN @CUR_B2C_CZ
   
      FETCH NEXT FROM @CUR_B2C_CZ INTO @c_PickZone
                                    ,  @c_SkuGroup   
                                    ,  @c_PackZone   
   
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @c_LabelNo = ''                       -- Reset to generate new label
         SET @n_RemainingCube = @n_MaxCube_B2C
         WHILE 1 = 1
         BEGIN
            SELECT TOP 1 
                  @n_RowRef = pw.RowRef
               ,  @n_PickItemCube= pw.PickItemCube 
               ,  @n_StdCube = pw.StdCube
               ,  @n_Qty = pw.Qty
            FROM @t_ORDERS AS tor        
            JOIN #PICKDETAIL_WIP AS pw ON pw.Orderkey = tor.Orderkey    
            WHERE tor.DocType = 'E'   
            AND pw.PackStation = 0
            AND pw.UOM IN ('6', '7')
            AND pw.PickZone = @c_PickZone
            AND pw.SkuGroup = @c_SkuGroup
            AND pw.PackZone = @c_PackZone
            AND pw.CartonType = ''
            ORDER BY pw.Style
                  ,  pw.Color
                  ,  pw.Size
         
            IF @@ROWCOUNT = 0
            BEGIN
               BREAK
            END
         
            IF @n_StdCube > @n_MaxCube_B2C 
            BEGIN
               SET @n_Continue = 3  
               SET @n_err = 64005    
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Sku''s cube > Tote''s cube. (isp_RPT_TH_WAV_CZ_FCST)'     
               GOTO NEXT_WAVE
            END
         
            IF @n_RemainingCube < @n_StdCube OR @c_LabelNo = ''         --New Carton
            BEGIN
 
               SET @n_CartonSeqNo = @n_CartonSeqNo + 1
            
               SET @n_RemainingCube = @n_MaxCube_B2C
            END
  
            SET @n_Qty_ToPack = 0
            SET @n_Qty_ToPack = FLOOR (@n_RemainingCube / @n_StdCube)
 
            IF @n_Qty_ToPack > @n_Qty
            BEGIN
               SET @n_Qty_ToPack = @n_Qty
            END
         
            IF @n_Qty <> @n_Qty_ToPack
            BEGIN
               INSERT INTO #PICKDETAIL_WIP      
                  (  
                     Orderkey          
                  ,  Pickdetailkey     
                  ,  Storerkey         
                  ,  Sku               
                  ,  UOM               
                  ,  UOMQty            
                  ,  Qty               
                  ,  Lot               
                  ,  Loc               
                  ,  DropID            
                  ,  PickLoc           
                  ,  PickZone          
                  ,  PickLogicalloc    
                  ,  PackZone          
                  ,  PackStation       
                  ,  PickItemCube      
                  ,  PickItemWgt       
                  ,  SkuGroup          
                  ,  Style             
                  ,  Color             
                  ,  Size              
                  ,  PackQtyIndicator  
                  ,  StdCube           
                  ,  StdGrossWgt       
                  ,  [Length]          
                  ,  Width             
                  ,  Height            
                  ,  Status_CZ  
                  ,  CartonGroup 
                  ,  PackAccessQty      
                  )
               SELECT 
                     pw.Orderkey          
                  ,  pw.Pickdetailkey     
                  ,  pw.Storerkey         
                  ,  pw.Sku               
                  ,  pw.UOM               
                  ,  UOMQty = CASE WHEN pw.DropID = '' THEN pw.Qty - @n_Qty_ToPack ELSE pw.UOMQty END            
                  ,  Qty    = pw.Qty - @n_Qty_ToPack          
                  ,  pw.Lot               
                  ,  pw.Loc               
                  ,  pw.DropID            
                  ,  pw.PickLoc           
                  ,  pw.PickZone          
                  ,  pw.PickLogicalloc    
                  ,  pw.PackZone          
                  ,  pw.PackStation    
                  ,  PickItemCube = ((pw.Qty - @n_Qty_ToPack) / (1.00 * pw.PackQtyIndicator)) * pw.StdCube      
                  ,  PickItemWgt  = ((pw.Qty - @n_Qty_ToPack) / (1.00 * pw.PackQtyIndicator)) * pw.StdGrossWgt         
                  ,  pw.SkuGroup          
                  ,  pw.Style             
                  ,  pw.Color             
                  ,  pw.Size              
                  ,  pw.PackQtyIndicator  
                  ,  pw.StdCube           
                  ,  pw.StdGrossWgt       
                  ,  pw.[Length]          
                  ,  pw.Width             
                  ,  pw.Height  
                  ,  Status_CZ = 2
                  ,  pw.CartonGroup
                  ,  pw.PackAccessQty
               FROM #PICKDETAIL_WIP AS pw 
               WHERE pw.RowRef = @n_RowRef      
            END            

            UPDATE pw
               SET pw.LabelNo = @n_CartonSeqNo
                  ,pw.CartonType = @c_CartonType_B2C
                  ,pw.CartonSeqNo= @n_CartonSeqNo
                  ,pw.CartonCube = @n_MaxCube_B2C
                  ,pw.Qty = @n_Qty_ToPack
                  ,pw.PickItemCube = @n_Qty_ToPack * pw.StdCube
                  ,pw.PickItemWgt  = @n_Qty_ToPack * pw.StdGrossWgt  
                  ,pw.Status_CZ = CASE WHEN pw.Qty > @n_Qty_ToPack AND pw.Status_CZ = 0 THEN 1 ELSE pw.Status_CZ END--If Split record, remain status_CZ = 2
            FROM #PICKDETAIL_WIP AS pw  
            WHERE pw.RowRef = @n_RowRef
   
            SET @n_RemainingCube = @n_RemainingCube - (@n_StdCube * @n_Qty_ToPack)
         END
   
         FETCH NEXT FROM @CUR_B2C_CZ INTO  @c_PickZone
                                          ,@c_SkuGroup   
                                          ,@c_PackZone      
      END                              
      CLOSE @CUR_B2C_CZ
      DEALLOCATE @CUR_B2C_CZ
      ------------------------------------------------
      -- B2C Build Carton Type - END
      ------------------------------------------------ 
 
      ------------------------------------------------
      -- B2B Build Carton Type - START
      ------------------------------------------------ 
      INSERT INTO @t_OptimizeCZGroup_FC
          (
              CartonizationGroup
          ,   CartonType
          ,   [Cube]
          ,   MaxWeight
          ,   CartonLength
          ,   CartonWidth
          ,   CartonHeight
          )
      SELECT CartonizationGroup
          ,   oc.CartonType
          ,   oc.[Cube]
          ,   oc.MaxWeight
          ,   oc.CartonLength
          ,   oc.CartonWidth
          ,   oc.CartonHeight
      FROM #OptimizeCZGroup AS oc
      ORDER BY oc.RowRef
   
      SELECT TOP 1 @n_RowRef_FC = tocgf.RowRef
      FROM @t_OptimizeCZGroup_FC AS tocgf
      ORDER BY tocgf.RowRef DESC
   
      UPDATE @t_OptimizeCZGroup_FC
         SET [Cube]    = 9999.99
           , MaxWeight = 99.99
      WHERE RowRef = @n_RowRef_FC
      --(Wan04) - END - Move Out from Order Loop for Wan03
   
      SET @CUR_ORD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT   tor.Orderkey
            ,  tor.Loadkey
            ,  tor.[Route]
            ,  tor.ExternOrderkey
            ,  tor.DocType
      FROM @t_ORDERS AS tor
      ORDER BY tor.Orderkey
          
      OPEN @CUR_ORD
   
      FETCH NEXT FROM @CUR_ORD INTO @c_Orderkey
                                 ,  @c_Loadkey
                                 ,  @c_Route
                                 ,  @c_ExternOrderkey
                                 ,  @c_DocType
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF @n_debug = 1
         BEGIN
            PRINT 'START - @c_Orderkey: ' + @c_Orderkey
         END

         IF @c_DocType = 'E'
         BEGIN
            GOTO BUILD_PACK
         END
      
         ---------------------------------------------------------
         -- 2) For DP/DPP - Cartonization UOM IN ('6','7') - START
         ---------------------------------------------------------
      
         SET @n_CartonSeqNo = 0
         SELECT TOP 1 @n_CartonSeqNo = pw.CartonSeqNo
         FROM #PICKDETAIL_WIP AS pw
         WHERE pw.Orderkey = @c_Orderkey
         ORDER BY pw.CartonSeqNo DESC

         SET @n_PackAccessQty = NULL
         SET @n_SplitToAccessQty = 0                                               
         WHILE 1 = 1
         BEGIN
            SELECT TOP 1
                    @c_PickZone = pw.PickZone   
                  , @c_SkuGroup = pw.SkuGroup   
                  , @c_CartonGroup_B2B = pw.CartonGroup
                  , @n_PackAccessQty   = CASE WHEN @n_PackAccessQty = 0 THEN @n_PackAccessQty ELSE pw.PackAccessQty END
            FROM #PICKDETAIL_WIP AS pw 
            WHERE pw.Orderkey = @c_Orderkey    
            AND pw.PackStation = 0
            AND pw.UOM IN ('6', '7')
            AND pw.CartonType = ''
            AND pw.SplitToAccessQty IN (0, @n_SplitToAccessQty)                      
            AND EXISTS (SELECT 1 FROM #PICKDETAIL_WIP AS pw2
                        WHERE pw2.Orderkey = @c_Orderkey    
                        AND pw2.PackStation = 0
                        AND pw2.UOM IN ('6', '7')
                        AND pw2.CartonType = ''
                        AND pw2.PickZone = pw.PickZone
                        AND pw2.SkuGroup = pw.SkuGroup
                        AND pw2.Style = pw.Style
                        AND pw2.Sku = pw.Sku
                        AND pw2.SplitToAccessQty IN (0, @n_SplitToAccessQty)                            
                        GROUP BY pw2.Sku   
                        HAVING SUM(CASE WHEN FLOOR(pw2.Qty/pw2.PackQtyIndicator) = 0 THEN 1    
                                        ELSE FLOOR(pw2.Qty/pw2.PackQtyIndicator)               
                                        END
                                    ) > CASE WHEN @n_PackAccessQty = 0 THEN @n_PackAccessQty ELSE pw.PackAccessQty END
                        )
            GROUP BY pw.PickZone   
                  ,  pw.SkuGroup
                  ,  pw.CartonGroup
                  ,  pw.PackAccessQty
            ORDER BY pw.PickZone   
                  ,  pw.SkuGroup  
                  , MIN(pw.Color)                           
                  , MIN(pw.[Size])                          
                  , MIN(pw.PickLogicalloc)                  

            IF @@ROWCOUNT = 0 
            BEGIN
               IF @n_PackAccessQty = 0
               BEGIN
                  BREAK
               END
            
               SET @n_PackAccessQty = 0
               SET @n_SplitToAccessQty = 1                                          
               CONTINUE
            END
         
            WHILE 1 = 1
            BEGIN
               SELECT TOP 1 @c_CartonType_B2B = ocg.CartonType  
                           ,@n_MaxCube_B2B    = ocg.[Cube]  
                           ,@n_MaxWeight_B2B  = ocg.MaxWeight  
               FROM #OptimizeCZGroup AS ocg 
               WHERE ocg.CartonizationGroup = @c_CartonGroup_B2B
               ORDER BY ocg.RowRef DESC  
         
               TRUNCATE TABLE #OptimizeItemToPack;
            
               ;WITH ACCVOL(Storerkey, SKU, Color, Size, [Length], Width, Height, Quantity, RowRef, AccumulateCube, AccumulateWgt
                           ,RemainQtyCube, RemainQtyWgt, StdGrossWgt, SortID) AS
               (  SELECT pw.Storerkey
                        ,pw.Sku
                        ,pw.Color
                        ,pw.Size
                        ,pw.[Length]
                        ,pw.Width
                        ,pw.Height 
                        ,pw.Qty 
                        ,pw.RowRef     
                        ,AccumulateCube = SUM(pw.PickItemCube) OVER( ORDER BY pw.Style, pw.Color, pw.Size, pw.PickLogicalloc, pw.Sku, pw.RowRef )  
                        ,AccumulateWgt  = SUM(pw.PickItemWgt)  OVER( ORDER BY pw.Style, pw.Color, pw.Size, pw.PickLogicalloc, pw.Sku, pw.RowRef )  
                        ,RemainQtyCube = FLOOR((@n_MaxCube_B2B + pw.PickItemCube - SUM(pw.PickItemCube) OVER( ORDER BY pw.Style, pw.Color, pw.Size, pw.PickLogicalloc, pw.Sku, pw.RowRef )) / pw.StdCube)
                        ,RemainQtyWgt  = FLOOR((@n_MaxWeight_B2B + pw.PickItemWgt - SUM(pw.PickItemWgt) OVER( ORDER BY pw.Style, pw.Color, pw.Size, pw.PickLogicalloc, pw.Sku, pw.RowRef )) / pw.StdGrossWgt)
                        ,pw.StdGrossWgt  
                        ,SortID = ROW_NUMBER() OVER( ORDER BY pw.Style, pw.Color, pw.Size, pw.PickLogicalloc, pw.Sku, pw.RowRef )                 
                  FROM #PICKDETAIL_WIP AS pw 
                  WHERE pw.Orderkey = @c_Orderkey    
                  AND pw.PackStation = 0
                  AND pw.UOM IN ('6', '7')
                  AND pw.CartonType = ''
                  AND pw.PickZone  = @c_PickZone
                  AND pw.SkuGroup  = @c_SkuGroup
                  AND pw.SplitToAccessQty IN (0, @n_SplitToAccessQty)                     
                  AND EXISTS (SELECT 1 FROM #PICKDETAIL_WIP AS pw2
                              WHERE pw2.Orderkey = @c_Orderkey    
                              AND pw2.PackStation = 0
                              AND pw2.UOM IN ('6', '7')
                              AND pw2.CartonType = ''
                              AND pw2.PickZone = pw.PickZone
                              AND pw2.SkuGroup = pw.SkuGroup
                              AND pw2.Style = pw.Style
                              AND pw2.Sku = pw.Sku
                              AND pw2.SplitToAccessQty IN (0, @n_SplitToAccessQty)        
                              GROUP BY pw2.Sku   
                              HAVING SUM(CASE WHEN FLOOR(pw2.Qty/pw2.PackQtyIndicator) = 0 THEN 1    
                                              ELSE FLOOR(pw2.Qty/pw2.PackQtyIndicator)               
                                              END
                                        ) > @n_PackAccessQty
                              ) 
               )
               INSERT INTO #OptimizeItemToPack ( Storerkey, SKU, Dim1,Dim2,Dim3, Quantity, RowRef, OriginalQty, StdGrossWgt, SortID)
               SELECT a.Storerkey, a.SKU, a.[Length], a.Width, a.Height, a.Quantity, a.RowRef, a.Quantity, a.StdGrossWgt, a.SortID
               FROM ACCVOL AS a 
               WHERE a.AccumulateCube <= @n_MaxCube_B2B AND a.AccumulateWgt <= @n_MaxWeight_B2B
               UNION
               SELECT TOP 1 a.Storerkey, a.SKU, a.[Length], a.Width, a.Height                         -- Next 1 record > MaxCube OR > MaxWeight to pack  
                           , Quantity = CASE WHEN a.RemainQtyWgt > 0 AND a.RemainQtyWgt <= a.RemainQtyCube
                                             THEN a.RemainQtyWgt
                                             ELSE a.RemainQtyCube
                                             END
                           , a.RowRef, a.Quantity, a.StdGrossWgt, a.SortID 
               FROM ACCVOL AS a 
               WHERE a.SortID > 1
               AND (a.RemainQtyWgt > 0 AND a.RemainQtyCube > 0)
               AND (a.AccumulateCube > @n_MaxCube_B2B OR a.AccumulateWgt > @n_MaxWeight_B2B)
               UNION 
               SELECT TOP 1 a.Storerkey, a.SKU, a.[Length], a.Width, a.Height                         -- At least Use 1 record to pack  
                           , Quantity = CASE WHEN a.RemainQtyWgt <= 0 OR a.RemainQtyCube <= 0         
                                             THEN 1
                                             WHEN a.RemainQtyWgt > 0 AND a.RemainQtyWgt <= a.RemainQtyCube
                                             THEN a.RemainQtyWgt
                                             ELSE a.RemainQtyCube
                                             END
                           , a.RowRef, a.Quantity, a.StdGrossWgt, a.SortID 
               FROM ACCVOL AS a 
               WHERE a.SortID = 1
               AND (a.AccumulateCube > @n_MaxCube_B2B OR a.AccumulateWgt > @n_MaxWeight_B2B)
               ORDER BY a.SortID

               IF @@ROWCOUNT = 0 
               BEGIN
                  BREAK
               END
            
               SET @b_MinQty1ToPack = 0
               SELECT TOP 1 @b_MinQty1ToPack = CASE WHEN oitp.SortID = 1 AND oitp.Quantity = 1 THEN 1 ELSE 0 END
               FROM #OptimizeItemToPack AS oitp
               ORDER BY oitp.SortID DESC
            
               SET @c_CartonType_B2B_w = @c_CartonType_B2B
               SET @n_MaxCube_B2B_w = @n_MaxCube_B2B

               WHILE 1 = 1
               BEGIN 
                  DELETE FROM @t_OptimizeResult;        
               
                  INSERT INTO @t_OptimizeResult (ContainerID, AlgorithmID, IsCompletePack, ID, SKU, Qty)  
                  EXEC isp_SubmitToCartonizeAPI  
                       @c_CartonGroup = @c_CartonGroup_B2B   
                     , @c_CartonType  = @c_CartonType_B2B_w    
                     , @b_Success     = @b_Success       OUTPUT  
                     , @n_Err         = @n_Err           OUTPUT  
                     , @c_ErrMsg      = @c_ErrMsg        OUTPUT 
                     , @b_Debug       = 0  

                  IF @b_Success = 0  
                  BEGIN  
                     SET @n_Continue = 3  
                     SET @n_err = 64010    
                     SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing isp_SubmitToCartonizeAPI. (isp_RPT_TH_WAV_CZ_FCST)'     
                                 + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '     
                     GOTO NEXT_WAVE    
                  END  
  
                  SET @c_IsCompletePack = ''  
                  SELECT @c_IsCompletePack = ore.IsCompletePack
                        ,@c_Sku_Optimize  = ore.Sku 
                        ,@n_Qty_Optimize  = ore.Qty
                  FROM @t_OptimizeResult AS ore 
               
               
                  IF @c_IsCompletePack IN('','FAIL') OR @c_CartonType_B2B_w = @c_CartonType_B2B       
                  BEGIN
                     SET @n_ID_ToPack = 0
                     SET @n_Qty_ToPack = 0
                     SET @n_QtyRemain_ToPack = 0
                     SELECT TOP 1 @n_ID_ToPack  = oitp.ID
                                 ,@c_Sku_ToPack = oitp.Sku
                                 ,@n_Qty_ToPack = oitp.Quantity
                                 ,@n_OrignalQty_ToPack  = oitp.OriginalQty
                     FROM #OptimizeItemToPack AS oitp
                     ORDER BY oitp.ID DESC
                  
                     TRUNCATE TABLE #ItemToPackBySku;
                     ;WITH gs AS 
                     (  SELECT oitp.ID, oitp.RowRef, oitp.Storerkey, oitp.Sku, oitp.Quantity, oitp.OriginalQty
                        FROM #OptimizeItemToPack AS oitp
                        WHERE oitp.ID = @n_ID_ToPack
                        UNION ALL
                        SELECT ID = gs.ID - 1, oitp.RowRef, oitp.Storerkey, oitp.Sku, oitp.Quantity, oitp.OriginalQty
                        FROM gs
                        JOIN #OptimizeItemToPack AS oitp ON gs.ID - 1 = oitp.ID
                        WHERE oitp.Sku = @c_Sku_ToPack
                     )
                     INSERT INTO #ItemToPackBySku
                     SELECT gs.ID, gs.RowRef, gs.Storerkey, gs.Sku, gs.Quantity, gs.OriginalQty
                     FROM gs
                     ORDER BY gs.ID
                  
                     SELECT @n_SkuQty_ToPack = SUM(itpbs.Quantity) 
                        ,   @n_SkuOrigQty_ToPack = SUM(itpbs.OriginalQty)
                        ,   @n_SkuItemToPackCnt = COUNT(1)
                     FROM #ItemToPackBySku AS itpbs
                     WHERE itpbs.SKU = @c_Sku_ToPack
                     GROUP BY itpbs.Storerkey, itpbs.SKU
                  END                                                                                
               
               
                  IF @c_IsCompletePack = 'TRUE'    
                  BEGIN
                       --Access Qty = 2
                     --TO_pack = 8,  remain =  4, original = 12      -- Pack to current  
                     --TO_pack = 10, remain =  2, original = 12      -- pack to new -- know as it is fit
                     --to_pack = 2,  remain = 10, original = 12      -- pack to new
                  
                     SET @n_TotalToPack = 0                                                                 
                     SELECT @n_TotalToPack = SUM(pw.Qty)                                                    
                     --FROM #OptimizeItemToPack AS oitp                                                     
                     FROM #PICKDETAIL_WIP AS pw                                                             
                     WHERE pw.Orderkey = @c_Orderkey                                                        
                     AND pw.PackStation = 0                                                                 
                     AND pw.UOM IN ('6', '7')                                                               
                     AND pw.CartonType = ''                                                                 
                     AND pw.PickZone  = @c_PickZone                                                         
                     AND pw.SkuGroup  = @c_SkuGroup                                                         
                     AND pw.Sku = @c_Sku_ToPack                                                                                                     
                     AND pw.SplitToAccessQty IN (0, @n_SplitToAccessQty)   
                     GROUP BY pw.Orderkey                                                                   
                  
                     SET @n_Qty_ToUpd = @n_Qty_ToPack                                                       
                     SET @n_QtyRemain_ToPack = @n_TotalToPack - @n_Qty_ToPack                               
                  
                     IF @n_SkuQty_ToPack > @n_Qty_ToPack                   
                     BEGIN

                        SET @n_Qty_ToUpd = @n_SkuQty_ToPack                                                 
                        SET @n_QtyRemain_ToPack = @n_TotalToPack - @n_SkuQty_ToPack                         
                     END                                                                                    
                  
                     IF @n_Qty_ToUpd <= @n_PackAccessQty
                     BEGIN
                        SET @n_Qty_ToUpd = 0
                     END
                  
                     IF @n_QtyRemain_ToPack > 0 AND @n_QtyRemain_ToPack <= @n_PackAccessQty 
                     BEGIN
                        SET @n_Qty_ToUpd = 0
                     END
                  
                     IF @n_Qty_ToUpd > 0  
                     BEGIN                  
                        SET @n_Qty_ToPack = @n_Qty_ToUpd
                     END
                  END
                  ELSE
                  BEGIN         
                     IF @c_CartonType_B2B_w <> @c_CartonType_B2B -- If Not Large Carton and it is not able to fit into current cartontype, use previous fit cartontype
                     BEGIN
                        BREAK
                     END
               
                     IF @c_IsCompletePack = ''-- Sku's LxWxH > Carton's LxWxH, prompt error 
                     OR @b_MinQty1ToPack = 1  -- Prompt Error if Qty 1 cannot fit in
                     BEGIN
                        SET @n_Continue = 3
                        SET @n_Err = 64015
                        SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Sku: ' + RTRIM(@c_Sku_ToPack)+ ' cannot fit into Carton. (isp_RPT_TH_WAV_CZ_FCST)'     
                                 + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '     
                        GOTO NEXT_WAVE   
                     END
                  
                     --Access Qty = 2
                     --TO_pack = 8,  remain =  4, original = 12      -- Pack to current  
                     --TO_pack = 10, remain =  2, original = 12      -- pack to new --does not know as not send to API
                     --to_pack = 2,  remain = 10, original = 12      -- pack to new
                  
                     -- Reduce By 1 if cannot fit into Large Carton
                     --SET @n_Qty_ToUpd = @n_Qty_ToPack - 1          --(Wan08)  
                     SET @n_QtyRemain_ToPack = 0                   
    
                     SET @n_Qty_ToUpd = @n_SkuQty_ToPack - 1         --(Wan08)    
                  
                     IF @n_Qty_ToUpd <= @n_PackAccessQty             --Comparing Total Qty of Sku against PackAccessQty, 
                     BEGIN
                        SET @n_Qty_ToUpd = 0
                     END
                     ELSE
                     BEGIN
                        SET @n_Qty_ToUpd = @n_Qty_ToPack - 1         --Reducing qty for Last record of sku
                     END
                  END

                  IF @n_Qty_ToUpd = 0     --Delete current to pack to new carton, need to check able to delete before execute               
                  BEGIN
                     SELECT @n_ItemToPackCnt = COUNT(1) 
                     FROM #OptimizeItemToPack AS oitp 

                     SET @n_ItemToPackCnt = @n_ItemToPackCnt - @n_SkuItemToPackCnt 
                  
                     --Check to Handle multi record with 1 unique sku fail to send API 
                     SET @b_RemoveLastRecord = 0
                     IF @n_ItemToPackCnt = 0 AND @n_Qty_ToPack < @n_SkuQty_ToPack
                     BEGIN
                        SET @n_ItemToPackCnt = @n_SkuItemToPackCnt - 1
                        SET @b_RemoveLastRecord = 1
                     END

                     IF @n_ItemToPackCnt = 0 
                     BEGIN
                        IF @c_IsCompletePack = 'FALSE' AND @n_PackAccessQty = 0 
                        BEGIN
                           SET @c_CartonType_B2B = ''
                           BREAK
                        END 
                        -------------------------------------------------------------------------------------------------------------------------------------
                        --IF @c_IsCompletePack = 'FALSE' AND @n_PackAccessQty > 0 THEN Update Sku to SplitAccessQty
                        --IF @c_IsCompletePack = 'TRUE'  AND @n_Qty_ToPack <= @n_PackAccessQty AND @n_PackAccessQty > 0 THEN Update Sku to SplitAccessQty
                        -------------------------------------------------------------------------------------------------------------------------------------
         
                        -------------------------------------------------------------------------------------------------------------------------------------
                        -- aceeesqty = 2, to_pack = 11, remain = 1, original = 12, then to_pack = 10  and split 10 and 2 with no carton type, take 10 to submit API, pack 10
                        -- aceeesqty = 7, to_pack = 11, remain = 2, original = 13, then to_pack = 12  and split  2 with no carton type, take 12 to submit API, pack 12
                        -------------------------------------------------------------------------------------------------------------------------------------
                        IF @c_IsCompletePack = 'TRUE' AND @n_PackAccessQty > 0 AND @n_SkuQty_ToPack > @n_PackAccessQty
                           AND @n_QtyRemain_ToPack > 0 AND @n_QtyRemain_ToPack <= @n_PackAccessQty 
                        BEGIN
                           IF @n_SkuOrigQty_ToPack - @n_PackAccessQty <= @n_PackAccessQty
                           BEGIN
                              SET @n_Qty_ToUpd  = @n_SkuOrigQty_ToPack - @n_PackAccessQty
                              SET @n_Qty_ToPack = @n_Qty_ToUpd
                           END
                           ELSE
                           BEGIN
                              SET @n_Qty_ToUpd = @n_SkuOrigQty_ToPack - @n_PackAccessQty
                              IF @n_Qty_ToPack > @n_SkuQty_ToPack - @n_Qty_ToUpd 
                              BEGIN
                                 SET @n_Qty_ToUpd = @n_Qty_ToPack - (@n_SkuQty_ToPack - @n_Qty_ToUpd)
                              END
                              ELSE
                              BEGIN
                                 SET @n_Qty_ToDel = @n_SkuQty_ToPack - @n_Qty_ToUpd    
                                 SET @n_ID_ToUpd = @n_ID_ToPack
                              
                                 WHILE 1 = 1 AND @n_Qty_ToDel > 0
                                 BEGIN
                                    SELECT TOP 1 @n_ID_ToUpd = oitp.ID
                                                ,@n_Qty_ToPack = oitp.Quantity
                                    FROM #OptimizeItemToPack AS oitp  
                                    WHERE oitp.ID <= @n_ID_ToUpd  
                                    ORDER BY oitp.ID DESC
                              
                                    IF @@ROWCOUNT = 0 
                                    BEGIN
                                       BREAK
                                    END 

                                    IF @n_Qty_ToPack <= @n_Qty_ToDel
                                    BEGIN
                                       DELETE oitp                
                                       FROM #OptimizeItemToPack AS oitp  
                                       WHERE oitp.ID = @n_ID_ToUpd  
                                    END
                                    ELSE
                                    BEGIN
                                       UPDATE oitp 
                                          SET oitp.Quantity = oitp.Quantity - @n_Qty_ToDel
                                       FROM #OptimizeItemToPack AS oitp  
                                       WHERE oitp.ID = @n_ID_ToUpd 
                                    END
                                    SET @n_Qty_ToDel = @n_Qty_ToDel - @n_Qty_ToPack
                                 END
                                 SET @n_Qty_ToUpd = 0
                                 SET @n_Qty_ToPack = @n_SkuQty_ToPack
                              END
                           END   
                        END
                     END
                  
                     IF @c_IsCompletePack = 'TRUE' AND @n_Qty_ToUpd = 0
                     BEGIN
                        SET @n_Qty_ToPack = @n_SkuQty_ToPack
                     END
                  
                     IF @n_ItemToPackCnt > 0 OR (@n_Qty_ToPack <= @n_PackAccessQty AND @n_ItemToPackCnt = 0)
                     BEGIN
                        --Check to Handle multi record with 1 unique sku fail to send API
                        --If Mix Sku, delete all records for the sku and send API again
                        --If 1 sku, delete last record and send API again
                        IF @b_RemoveLastRecord = 0 -- Mix Sku. delete all sku and submit API to check 
                        BEGIN
                           DELETE oitp               
                           FROM #OptimizeItemToPack AS oitp  
                           JOIN #ItemToPackBySku AS itpbs ON itpbs.ID = oitp.ID                    
                        END 
                        ELSE
                        BEGIN                      -- 1 Sku. delete last record and submit API to check 
                           DELETE oitp               
                           FROM #OptimizeItemToPack AS oitp  
                           WHERE oitp.ID = @n_ID_ToPack  
                        END
                     END

                     IF @n_ItemToPackCnt > 0 
                     BEGIN 
                        CONTINUE 
                     END

                     ----------------------------
                     --When @n_PackAccessQty > 0
                     ----------------------------
                     IF @n_Qty_ToPack <= @n_PackAccessQty AND @n_ItemToPackCnt = 0
                     BEGIN
                        UPDATE pw                                   
                        SET pw.SplitToAccessQty = 1                
                        FROM #ItemToPackBySku AS itpbs 
                        JOIN #PICKDETAIL_WIP AS pw ON pw.RowRef = itpbs.RowRef      
                        BREAK
                     END
                  END  -- IF @n_Qty_ToUpd = 0

                  IF @n_Qty_ToUpd > 0 AND @n_Qty_ToUpd <> @n_Qty_ToPack  -- Reduce Qty to send to API to check if fit or split record to be process by <= access qty
                  BEGIN
                     UPDATE oitp
                        SET oitp.Quantity = @n_Qty_ToUpd
                     FROM #OptimizeItemToPack AS oitp
                     WHERE oitp.ID = @n_ID_ToPack
                  
                     IF @c_CartonType_B2B = ''
                     BEGIN
                        BREAK
                     END
                  
                     IF NOT (@c_IsCompletePack = 'TRUE' AND @n_Qty_ToUpd > @n_PackAccessQty AND @n_Qty_ToUpd < @n_Qty_ToPack)
                     BEGIN
                        CONTINUE
                     END
                  END 

                  -----------------------------------------
                  -- Try to Get Smaller Box that can fit in
                  -----------------------------------------
                  IF @c_IsCompletePack = 'TRUE'    -- If Able to fit, Check if able to fit into smaller carton type
                  BEGIN
                     SET @c_CartonType_B2B = @c_CartonType_B2B_w
                     SET @n_MaxCube_B2B = @n_MaxCube_B2B_w
                  
                     SELECT TOP 1 
                                @c_CartonType_B2B_w = ocg.CartonType  
                              , @n_MaxCube_B2B_w    = ocg.[Cube]  
                              , @n_MaxWeight_B2B_w  = ocg.MaxWeight  
                     FROM #OptimizeCZGroup AS ocg 
                     WHERE ocg.CartonizationGroup = @c_CartonGroup_B2B
                     AND ocg.[Cube] < @n_MaxCube_B2B_w
                     AND EXISTS (SELECT 1 FROM #OptimizeItemToPack AS oitp 
                                 GROUP BY oitp.Storerkey
                                 HAVING SUM(oitp.Quantity * oitp.StdGrossWgt) <= ocg.[MaxWeight]
                                )
                     ORDER BY ocg.RowRef DESC 
            
                     IF @@ROWCOUNT = 0             --If No Smaller CartonType, Use the previous fit carton type
                     BEGIN
                        SET @c_CartonType_B2B = @c_CartonType_B2B_w
                        SET @n_MaxCube_B2B = @n_MaxCube_B2B_w
                        BREAK
                     END
        
                     CONTINUE                      --Continue to submit to API to check if fit smaller carton type
                  END
               END   
         
               IF NOT EXISTS ( SELECT 1 FROM #OptimizeItemToPack AS oitp)
               BEGIN
                  BREAK
               END 

               IF @c_CartonType_B2B <> ''
               BEGIN
                  SET @n_CartonSeqNo = @n_CartonSeqNo + 1     
               END
            
               SET @b_SplitPickdetail = 0
         
               SELECT @b_SplitPickdetail = 1
               FROM #OptimizeItemToPack AS oitp
               JOIN #PICKDETAIL_WIP AS pw ON pw.RowRef = oitp.RowRef        
               WHERE pw.Qty > oitp.Quantity
         
               IF @b_SplitPickdetail = 1 
               BEGIN
                  INSERT INTO #PICKDETAIL_WIP      
                     (  
                        Orderkey          
                     ,  Pickdetailkey     
                     ,  Storerkey         
                     ,  Sku               
                     ,  UOM               
                     ,  UOMQty            
                     ,  Qty               
                     ,  Lot               
                     ,  Loc               
                     ,  DropID            
                     ,  PickLoc           
                     ,  PickZone          
                     ,  PickLogicalloc    
                     ,  PackZone          
                     ,  PackStation       
                     ,  PickItemCube      
                     ,  PickItemWgt       
                     ,  SkuGroup          
                     ,  Style             
                     ,  Color             
                     ,  Size              
                     ,  PackQtyIndicator  
                     ,  StdCube           
                     ,  StdGrossWgt       
                     ,  [Length]          
                     ,  Width             
                     ,  Height            
                     ,  Status_CZ   
                     ,  CartonGroup
                     ,  PackAccessQty      
                     )
                  SELECT 
                        pw.Orderkey          
                     ,  pw.Pickdetailkey     
                     ,  pw.Storerkey         
                     ,  pw.Sku               
                     ,  pw.UOM               
                     ,  UOMQty = CASE WHEN pw.DropID = '' THEN pw.Qty - oitp.Quantity ELSE pw.UOMQty END            
                     ,  Qty    = pw.Qty - oitp.Quantity          
                     ,  pw.Lot               
                     ,  pw.Loc               
                     ,  pw.DropID            
                     ,  pw.PickLoc           
                     ,  pw.PickZone          
                     ,  pw.PickLogicalloc    
                     ,  pw.PackZone          
                     ,  pw.PackStation    
                     ,  PickItemCube = ((pw.Qty - oitp.Quantity) / (1.00 * pw.PackQtyIndicator)) * pw.StdCube      
                     ,  PickItemWgt  = ((pw.Qty - oitp.Quantity) / (1.00 * pw.PackQtyIndicator)) * pw.StdGrossWgt         
                     ,  pw.SkuGroup          
                     ,  pw.Style             
                     ,  pw.Color             
                     ,  pw.Size              
                     ,  pw.PackQtyIndicator  
                     ,  pw.StdCube           
                     ,  pw.StdGrossWgt       
                     ,  pw.[Length]          
                     ,  pw.Width             
                     ,  pw.Height  
                     ,  Status_CZ = 2
                     ,  pw.CartonGroup
                     ,  pw.PackAccessQty
                  FROM #OptimizeItemToPack AS oitp
                  JOIN #PICKDETAIL_WIP AS pw ON pw.RowRef = oitp.RowRef        
                  WHERE pw.Qty > oitp.Quantity
               END   
            
               UPDATE pw
                  SET pw.CartonType  = CASE WHEN @c_CartonType_B2B <> '' THEN @c_CartonType_B2B ELSE pw.CartonType END
                     , pw.CartonSeqNo = CASE WHEN @c_CartonType_B2B <> '' THEN @n_CartonSeqNo ELSE pw.CartonSeqNo END
                     , pw.CartonCube  = CASE WHEN @c_CartonType_B2B <> '' THEN @n_MaxCube_B2B ELSE pw.CartonCube END
                     , pw.Qty = oitp.Quantity
                     , pw.PickItemCube = oitp.Quantity * pw.StdCube
                     , pw.PickItemWgt  = oitp.Quantity * pw.StdGrossWgt
                     , pw.Status_CZ = CASE WHEN pw.Qty > oitp.Quantity AND pw.Status_CZ = 0 THEN 1 ELSE pw.Status_CZ END--If Split record, remain status_CZ = 2
                     , pw.SplitToAccessQty = CASE WHEN @c_CartonType_B2B = '' THEN 1 ELSE 0 END                 
               FROM #OptimizeItemToPack AS oitp
               JOIN #PICKDETAIL_WIP AS pw ON pw.RowRef = oitp.RowRef
            END
         END
         ---------------------------------------------------------
         -- 2) For DP/DPP - Cartonization UOM IN ('6','7') - END 
         ---------------------------------------------------------
         BUILD_PACK: 
      
         IF @n_debug = 1
         BEGIN
            SELECT @c_DocType '@c_DocType',pw.UOM, pw.dropid, pw.CartonType, pw.CartonSeqNo,pw.cartoncube, pw.PickItemCube, pw.PickItemWgt, *
            FROM #PICKDETAIL_WIP AS pw WHERE pw.Orderkey = @c_Orderkey
            ORDER BY pw.CartonSeqNo, pw.UOM, pw.CartonType
         END
      
         SET @n_RecCnt = 0
         SET @c_Sku = ''
         SELECT TOP 1 
                  @n_RecCnt = 1
                , @c_Sku = RTRIM(pw.Sku)
         FROM #PICKDETAIL_WIP AS pw 
         WHERE pw.Orderkey = @c_Orderkey AND pw.CartonType = ''
         ORDER BY pw.RowRef
            
         IF @n_RecCnt = 1
         BEGIN
            SET @n_continue = 3  
            SET @n_Err = 64020
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Shipment Order without carton type found, Orderkey: ' + @c_Orderkey + ', Sku: ' + @c_Sku
                         + '. (isp_RPT_TH_WAV_CZ_FCST)' 
            GOTO NEXT_WAVE      
         END
    
         FETCH NEXT FROM @CUR_ORD INTO @c_Orderkey
                                    ,  @c_Loadkey
                                    ,  @c_Route
                                    ,  @c_ExternOrderkey
                                    ,  @c_DocType
      END
      CLOSE @CUR_ORD
      DEALLOCATE @CUR_ORD 

      NEXT_WAVE:
      IF @n_Continue = 3
      BEGIN
         INSERT INTO #RPTCZFCST ( Wavekey, Loadkey, Orderkey, ExternOrderkey, TotalCarton, ErrMsg)
         SELECT Wavekey = @c_Wavekey, Loadkey = '', Orderkey = '', ExternOrderkey  = '', TotalCarton = 0, ErrMsg = @c_ErrMsg
      END
      ELSE
      BEGIN
         INSERT INTO #RPTCZFCST ( Wavekey, Loadkey, Orderkey, ExternOrderkey, TotalCarton, ErrMsg)
         SELECT Wavekey = @c_Wavekey, tor.Loadkey, tor.Orderkey, tor.ExternOrderkey, TotalCarton = COUNT(DISTINCT pw.CartonSeqNo), ErrMsg = ''
         FROM @t_ORDERS AS tor
         JOIN #PICKDETAIL_WIP AS pw ON tor.Orderkey = pw.Orderkey
         GROUP BY tor.Loadkey
               ,  tor.Loadkey
               ,  tor.Orderkey
               ,  tor.ExternOrderkey

      END      
      FETCH NEXT FROM @CUR_WV INTO @c_Wavekey 
   END
   CLOSE @CUR_WV
   DEALLOCATE @CUR_WV
QUIT_SP:
   SELECT r.Wavekey,  r.Loadkey, r.Orderkey, r.ExternOrderkey, r.TotalCarton, r.ErrMsg
   FROM #RPTCZFCST AS r
   
   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END  
   RETURN 
END -- procedure

GO