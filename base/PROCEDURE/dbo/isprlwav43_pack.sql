SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: ispRLWAV43_PACK                                         */
/* Creation Date: 2021-07-15                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-17299 - RG - Adidas Release Wave                        */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 2.3                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2021-07-15  Wan      1.0   Created.                                  */
/* 2021-09-28  Wan      1.0   DevOps Combine Script.                    */
/* 2021-10-21  Wan01    1.1   PHWMS Issue fixed                         */
/* 2021-10-22  Wan02    1.1   IDWMS UAT Issue fixed                     */
/* 2021-10-27  Wan03    1.2   Fixed Cannot Find Cartontype for UCC (FC) */
/* 2021-10-28  Wan04    1.3   Fixed Create @t_OptimizeCZGroup_FC record */
/*                            Once for B2B FC cartanization             */
/* 2021-11-05  Wan04    1.4   ID -Spilt Pickdetail to include Channel_ID*/
/* 2021-12-07  Wan05    1.5   To Fixed Inifinity Loop to Submit API     */
/* 2022-01-20  Wan06    1.6   To Fixed Inifinity Loop to Submit API     */
/*                            New Fixed if Last record <= packaccess    */
/* 2022-02-09  Wan07    1.7   CR 3.0 Link Deviceprofile by storerkey    */ 
/*                            Fixed. For allocated stock from DPBULK,use*/ 
/*                            DBBULK's PickZone to find PackStation     */
/*                            regardless if there is Home Loc setup.    */
/* 2022-03-18  Wan08    1.8   WMS-19219 - RG -Adidas Cartonization Logic*/
/*                            Update                                    */
/* 2022-04-06  Wan09    1.9   Fixed to remove last record and send API  */
/*                            if mutli record for 1 unique sku cannot fix*/
/*                            into Box                                  */
/* 2022-04-06  Wan10    2.0   Fixed b2b Uom = 2 to get large cartontype */  
/* 2022-07-19  Wan11    2.1   WMS-19522 - RG - Adidas SEA - Release Wave*/
/*                            on DP Loc Sequence                        */
/* 2022-08-10  Wan12    2.2   WMS-20419 -TH-Adidas Pre-Cartonization New*/
/*                            Logic (Customize)                         */
/* 2022-10-18  Wan13    2.3   Fixed. @n_Status_FC not initialize for new*/
/*                            orderkey                                  */
/************************************************************************/
CREATE PROC [dbo].[ispRLWAV43_PACK]
   @c_Wavekey     NVARCHAR(10)    
,  @b_Success     INT            = 1   OUTPUT
,  @n_Err         INT            = 0   OUTPUT
,  @c_ErrMsg      NVARCHAR(255)  = ''  OUTPUT
,  @n_debug       INT            = 0 
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt          INT         = 0
         , @n_Continue           INT         = 1

         , @n_RowRef             INT         = 0
         , @n_RowRef_FC          INT         = 0      --(Wan03)
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
         , @n_RecCnt             NVARCHAR(20) = ''       --(Wan03)
         
         , @n_SplitToAccessQty   INT         = 0         --Wan02 
         , @n_Status_FC          INT         = 0         --Wan12   
         , @b_1SkuFullCarton     INT         = 0         --Wan12  
         , @b_ReduceToFit        INT         = 0         --Wan12                                  
         , @c_FullSkuCarton      NVARCHAR(30)= ''        --Wan12
         
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
         
         , @c_SkuGroupSkipOptim  NVARCHAR(30)= ''        --(Wan11)
                
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
         , @n_TotalToPack        INT         = 0         --(Wan06) 
                                                        
         , @n_SkuQty_ToPack      INT         = 0         --(Wan08)
         , @n_SkuOrigQty_ToPack  INT         = 0         --(Wan08)
         , @n_SkuItemToPackCnt   INT         = 0         --(Wan08)
         , @n_Qty_ToDel          INT         = 0         --(Wan08)
         
         , @b_RemoveLastRecord   INT         = 0         --(Wan09)
                  
         , @b_MinQty1ToPack      BIT         = 0
         
         , @n_ItemToPackCnt      INT         = 0 
         , @b_SplitPickdetail    INT         = 0

         , @c_PickDetailKey      NVARCHAR(10)= ''
         , @c_Storerkey          NVARCHAR(15)= ''
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
         --, @CUR_DELPCK           CURSOR
 
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

   --(Wan03)      
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
         
   --(Wan05) - START - Change to use Variable Table      
   DECLARE @t_OptimizeResult     TABLE
         (  ContainerID          NVARCHAR(10)   NULL  DEFAULT('')    
         ,  AlgorithmID          NVARCHAR(10)   NULL  DEFAULT('')  
         ,  IsCompletePack       NVARCHAR(10)   NULL  DEFAULT('')  
         ,  ID                   INT            NULL  DEFAULT('')  
         ,  SKU                  NVARCHAR(20)   NULL  DEFAULT('')  
         ,  Qty                  INT            NULL  DEFAULT(0)  
         )    
   --(Wan05) - END
   --      
   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''
  
   IF OBJECT_ID('tempdb..#PICKDETAIL_WIP','U') IS NULL
   BEGIN
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
      ,  PickLoc           NVARCHAR(10) DEFAULT('')         --RPF toLoc (DP/DPP/PackStation/SortStationGroup) or Pickdetail.Loc
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
      ,  Status_FC         INT          DEFAULT(0)    --(Wan12) 0: Not Process, 1: In Progress, 9: Done                
      )
   END

   IF OBJECT_ID('tempdb..#OptimizeCZGroup','U') IS NULL
   BEGIN
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
   END

   IF OBJECT_ID('tempdb..#OptimizeItemToPack','U') IS NULL
   BEGIN
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
   END
   
   --(Wan08) - START
   IF OBJECT_ID('tempdb..#ItemToPackBySku','U') IS NULL
   BEGIN
      CREATE TABLE #ItemToPackBySku 
         (
            ID          INT            NOT NULL DEFAULT(0)  PRIMARY KEY
         ,  RowRef      INT            NOT NULL DEFAULT(0)
         ,  Storerkey   NVARCHAR(15)   NOT NULL DEFAULT('') 
         ,  SKU         NVARCHAR(20)   NOT NULL DEFAULT('')
         ,  Quantity    INT            NOT NULL DEFAULT(0)
         ,  OriginalQty INT            NOT NULL DEFAULT(0)
         )
   END
   --(Wan08) - END
   
   --(Wan05) - START - Change to use Variable Table
   --IF OBJECT_ID('tempdb..@t_OptimizeResult','U') IS NULL  
   --BEGIN  
   --   CREATE TABLE #OptimizeResult  
   --      (  ContainerID       NVARCHAR(10)   NULL  DEFAULT('')  
   --      ,  AlgorithmID       NVARCHAR(10)   NULL  DEFAULT('')
   --      ,  IsCompletePack    NVARCHAR(10)   NULL  DEFAULT('')
   --      ,  ID                INT            NULL  DEFAULT('')
   --      ,  SKU               NVARCHAR(20)   NULL  DEFAULT('')
   --      ,  Qty               INT            NULL  DEFAULT(0)
   --      )  
   --END 
   --(Wan05) - END - Change to use Variable Table

   BEGIN TRAN

   INSERT INTO @t_ORDERS
        ( Wavekey, Loadkey, Orderkey, Facility, Storerkey, [Route], ExternOrderkey, DocType, Ecom_Single_Flag )
   SELECT WD.Wavekey, OH.Loadkey, OH.Orderkey, OH.Facility, OH.Storerkey, OH.[Route], OH.ExternOrderkey, OH.DocType, OH.ECOM_SINGLE_Flag
   FROM WAVEDETAIL WD WITH (NOLOCK)
   JOIN ORDERS OH WITH (NOLOCK) ON WD.Orderkey = OH.Orderkey
   WHERE WD.Wavekey = @c_Wavekey
   
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
      GOTO QUIT_SP
   END
   
   SET @c_CartonGroup_B2C = ''
   SELECT @c_CartonGroup_B2C = dbo.fnc_GetParamValueFromString('@c_CartonGroup_B2C', @c_Release_Opt5, @c_CartonGroup_B2C) 
   
   --(Wan11) CR 2.0 - START   
   SET @c_SkuGroupSkipOptim = '' 
   SELECT @c_SkuGroupSkipOptim = dbo.fnc_GetParamValueFromString('@c_SkuGroupSkipOptim', @c_Release_Opt5, @c_SkuGroupSkipOptim) 
   --(Wan11) CR 2.0 - END
   
   --(Wan12) - START CR1.5
   SET @c_FullSkuCarton = 'N'
   SELECT @c_FullSkuCarton = dbo.fnc_GetParamValueFromString('@c_FullSkuCarton', @c_Release_Opt5, @c_FullSkuCarton) 

   SET @n_Status_FC = '9'
   IF @c_FullSkuCarton = 'Y'
   BEGIN
      SET @n_Status_FC = '0'
   END
   --(Wan12) - END
   
   --(Wan12) - END
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
      ,  Status_FC                  --(Wan12)         
      )        
      
   SELECT
         p.Orderkey          
      ,  p.Pickdetailkey     
      ,  p.Storerkey         
      ,  p.Sku               
      ,  p.UOM               
      ,  p.UOMQty            
      ,  p.Qty               
      ,  p.Lot
      ,  p.Loc  
      ,  p.DropID             
      ,  PickLoc      = CASE WHEN td2.TaskDetailKey IS NULL THEN p.Loc ELSE td2.LogicalToLoc END 
      ,  PickItemCube = p.Qty * s2.stdcube       
      ,  PickItemWgt  = p.Qty * s2.stdgrosswgt        
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
      ,  PackAccessQty = CASE WHEN ISNULL(c.UDF02,'') = '' THEN '0' ELSE ISNULL(c.UDF02,'') END  
      ,  @n_Status_FC               --(Wan12)         
   FROM @t_ORDERS AS tor  
   JOIN dbo.PICKDETAIL AS p WITH (NOLOCK) ON p.Orderkey = tor.Orderkey  
   JOIN dbo.SKU AS s2 WITH (NOLOCK) ON s2.StorerKey = p.Storerkey AND s2.Sku = p.Sku
   JOIN dbo.CODELKUP AS c WITH (NOLOCK) ON  c.LISTNAME = 'SkuGroup'
                                        AND c.Code = s2.SkuGroup
                                        AND c.Storerkey = p.Storerkey
   LEFT OUTER JOIN dbo.TaskDetail AS td2 WITH (NOLOCK) ON  td2.TaskDetailKey = p.TaskDetailKey
                                                       AND td2.Caseid = p.DropID 
                                                       AND td2.TaskType  = 'RPF'  
   WHERE p.UOM IN ('2','6','7') 
   AND   p.Qty > 0 
   AND   p.[Status] < '5' 
   ORDER BY p.OrderKey 

   
   --Handle Share UCC Repl in Another Wave
   UPDATE pw
   SET pw.PickLoc = l2.Loc
   FROM @t_ORDERS AS tor        
   JOIN #PICKDETAIL_WIP AS pw ON pw.Orderkey = tor.Orderkey
   JOIN dbo.LOC AS l WITH (NOLOCK) ON pw.PickLoc = l.Loc
   JOIN dbo.SKUxLOC AS sul WITH (NOLOCK) ON sul.StorerKey = pw.Storerkey AND sul.Sku = pw.Sku AND sul.LocationType = 'PICK'
   JOIN dbo.LOC AS l2 WITH (NOLOCK) ON sul.Loc = l2.Loc AND l2.LocationType = 'DYNPPICK'
   WHERE pw.UOM = '7' 
   AND   l.LocationType NOT IN ('DPBULK', 'DYNPPICK')
   
   UPDATE pw
      SET pw.PickLogicalloc = l.LogicalLocation
         ,pw.PickZone     = CASE WHEN l.LocationType = 'DPBULK' THEN l.PickZone ELSE ISNULL(l2.PickZone,'') END                           --(Wan07)
         --,pw.PackZone     = ISNULL(c.Short,'')                                                                                          --(Wan07)
         --,pw.PackStation  = CASE WHEN c.Short = pw.PickLoc THEN 1 ELSE 0 END                                                            --(Wan07)
         --,pw.PickItemCube = CASE WHEN c.Short = pw.PickLoc                                                                              --(Wan07)
         --                        THEN pw.PickItemCube                                                                                   --(Wan07)
         --                        ELSE (pw.Qty / (1.00 * pw.PackQtyIndicator)) * pw.StdCube                                              --(Wan07)
         --                        END                                                                                                    --(Wan07)
         --,pw.PickItemWgt  = CASE WHEN c.Short = pw.PickLoc                                                                              --(Wan07)
         --                        THEN pw.PickItemWgt                                                                                    --(Wan07)
         --                        ELSE (pw.Qty / (1.00 * pw.PackQtyIndicator)) * pw.StdGrossWgt                                          --(Wan07)
         --                        END                                                                                                    --(Wan07)
         --,pw.[Length]= CASE WHEN c.Short = pw.PickLoc                                                                                   --(Wan07)
         --                   THEN pw.[Length]                                                                                            --(Wan07)
         --                   ELSE pw.[Length] / (1.00 * pw.PackQtyIndicator)                                                             --(Wan07)
         --                   END                                                                                                         --(Wan07)
         --,pw.Width   = CASE WHEN c.Short = pw.PickLoc                                                                                   --(Wan07)
         --                   THEN pw.Width                                                                                               --(Wan07)
         --                   ELSE pw.Width    / (1.00 * pw.PackQtyIndicator)                                                             --(Wan07)
         --                   END                                                                                                         --(Wan07)
         --,pw.Height  = CASE WHEN c.Short = pw.PickLoc                                                                                   --(Wan07)
         --                   THEN pw.Height                                                                                              --(Wan07)
         --                   ELSE pw.Height   / (1.00 * pw.PackQtyIndicator)                                                             --(Wan07)
         --                   END                                                                                                         --(Wan07)
   FROM @t_ORDERS AS tor                                                                                                                  --(Wan07)
   JOIN #PICKDETAIL_WIP AS pw ON pw.Orderkey = tor.Orderkey
   JOIN dbo.LOC AS l WITH (NOLOCK) ON pw.PickLoc = l.Loc
   LEFT OUTER JOIN dbo.SKUxLOC AS sul WITH (NOLOCK) ON sul.StorerKey = pw.Storerkey AND sul.Sku = pw.Sku AND sul.LocationType = 'PICK'    --(Wan07)
   LEFT OUTER JOIN dbo.LOC AS l2 WITH (NOLOCK) ON sul.Loc = l2.Loc AND l2.LocationType = 'DYNPPICK'                                       --(Wan07)
   --LEFT OUTER JOIN dbo.CODELKUP AS c ON  c.LISTNAME  = 'ADPickZone'                                                                     --(Wan07)
   --                                  AND c.Code      = l2.PickZone
   --                                  AND c.Storerkey = pw.Storerkey
   --                                  AND c.code2     = tor.DocType

   --(Wan07) - START
   UPDATE pw  
        SET pw.PackZone = ISNULL(c.Short,'')    
         ,  pw.PackStation  = CASE WHEN c.Short = pw.PickLoc THEN 1 ELSE 0 END                                                            
         ,  pw.PickItemCube = CASE WHEN c.Short = pw.PickLoc 
                                   THEN pw.PickItemCube
                                   ELSE (pw.Qty / (1.00 * pw.PackQtyIndicator)) * pw.StdCube
                                   END
         ,  pw.PickItemWgt  = CASE WHEN c.Short = pw.PickLoc 
                                   THEN pw.PickItemWgt
                                   ELSE (pw.Qty / (1.00 * pw.PackQtyIndicator)) * pw.StdGrossWgt
                                   END
         ,  pw.[Length]= CASE WHEN c.Short = pw.PickLoc 
                              THEN pw.[Length]         
                              ELSE pw.[Length] / (1.00 * pw.PackQtyIndicator)  
                              END
         ,  pw.Width   = CASE WHEN c.Short = pw.PickLoc 
                              THEN pw.Width
                              ELSE pw.Width    / (1.00 * pw.PackQtyIndicator) 
                              END 
         ,  pw.Height  = CASE WHEN c.Short = pw.PickLoc
                              THEN pw.Height 
                              ELSE pw.Height   / (1.00 * pw.PackQtyIndicator) 
                              END                                                                                                                                                 
   FROM @t_ORDERS AS tor          
   JOIN #PICKDETAIL_WIP AS pw ON pw.Orderkey = tor.Orderkey
   LEFT OUTER JOIN dbo.CODELKUP AS c ON  c.LISTNAME  = 'ADPickZone'                                                                     
                                     AND c.Code      = pw.PickZone            -- Original Pick From Zone to PackStation
                                     AND c.Storerkey = pw.Storerkey
                                     AND c.code2     = tor.DocType
   --(Wan07) - END 
   
   UPDATE pw
      SET pw.PackZone = l.PickZone 
        , pw.PackStation  = CASE WHEN pw.PickLoc = l.pickzone THEN 1 ELSE 0 END
   FROM #PICKDETAIL_WIP AS pw
   JOIN dbo.PackTask AS pt WITH (NOLOCK) ON pt.Orderkey = pw.Orderkey AND pt.OrderMode LIKE 'M%'
   JOIN dbo.DeviceProfile AS dp WITH (NOLOCK) ON dp.DevicePosition = pt.DevicePosition
                                              AND dp.Storerkey = pw.Storerkey                --Wan07
   JOIN dbo.LOC AS l WITH (NOLOCK) ON l.Loc = dp.Loc
   
   
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
           
   ------------------------------------------------
   -- B2C Build Carton Type - START 
   -- 1) For UCC to PackStation 
   ------------------------------------------------ 
   ;WITH UCC_B2C (SeqNo, DropID, Cube_TTL, Wgt_TTL ) AS
   ( SELECT SeqNo = ROW_NUMBER() OVER (ORDER BY l.PickZone, pw.SkuGroup, l.LogicalLocation, pw.DropID )  
           ,pw.DropID, Cube_TTL = SUM(pw.PickItemCube), Wgt_TTL = SUM(pw.PickItemCube)
     FROM @t_ORDERS AS tor        
     JOIN #PICKDETAIL_WIP AS pw ON pw.Orderkey = tor.Orderkey
     JOIN dbo.LOC AS l WITH (NOLOCK) ON pw.Loc = l.Loc
     WHERE tor.DocType = 'E'   
     AND pw.PackStation= 1
     AND pw.UOM IN ('2','6')       -- Single and Multi
     GROUP BY pw.DropID
            , l.PickZone
            , pw.SkuGroup
            , l.LogicalLocation
            , pw.DropID
   ) 
  
   UPDATE pw
      SET pw.LabelNo = u.DropID
         ,pw.CartonType = @c_CartonType_B2C
         ,pw.CartonSeqNo= u.SeqNo
         ,pw.CartonCube = @n_MaxCube_B2C
   FROM #PICKDETAIL_WIP AS pw
   JOIN UCC_B2C AS u ON pw.DropID = u.DropID
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
   AND pw.PackStation = 0
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
         
         --(Wan08) - START Sku cannot fix into Tote 
         IF @n_StdCube > @n_MaxCube_B2C 
         BEGIN
            SET @n_Continue = 3  
            SET @n_err = 64005    
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Sku''s cube > Tote''s cube. (ispRLWAV43_PACK)'     
            GOTO QUIT_SP
         END
         --(Wan08) - END   Sku cannot fix into Tote 
         
         IF @n_RemainingCube < @n_StdCube OR @c_LabelNo = ''         --New Carton
         BEGIN
 
            SET @n_CartonSeqNo = @n_CartonSeqNo + 1
            
            SET @c_LabelNo = ''
            SET @b_success = 1  
            
            EXECUTE nspg_getkey  
                 @KeyName     = 'ADEcomToteLabel'  
               , @fieldlength = 10  
               , @keystring  = @c_LabelNo             OUTPUT  
               , @b_success  = @b_success             OUTPUT  
               , @n_err      = @n_err                 OUTPUT  
               , @c_errmsg   = @c_errmsg              OUTPUT
                       
            IF NOT @b_success = 1  
            BEGIN  
               SET @n_continue = 3
               GOTO QUIT_SP  
            END  
            
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
            SET pw.LabelNo = @c_LabelNo
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
  --(Wan04) - START - Move Out from Order Loop for Wan03
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
      -- 1) For UCC to PackStation, UOM = '2' - START
      ---------------------------------------------------------
      ;WITH UCC_B2B AS --(SeqNo, DropID, Cube_TTL, Wgt_TTL ) AS
      (  SELECT d.DropID                                             --(Wan01) 2021-10-21
               ,SeqNo = ROW_NUMBER() OVER ( ORDER BY d.PickZone, d.SkuGroup, d.LogicalLocation, d.DropID ) 
               , d.cartontype
               , d.[Cube]                              
         FROM (
            SELECT TOP 1 WITH TIES
                    pw.DropID
                  , SeqNo = ROW_NUMBER() OVER ( PARTITION BY ocg.[Cube], ocg.MaxWeight, ocg.CartonType
                                                ORDER BY l.PickZone, pw.SkuGroup, l.LogicalLocation, pw.DropID
                                                )               
           
                  , ocg.cartontype
                  , ocg.[Cube]
                  , l.PickZone
                  , pw.SkuGroup
                  , l.LogicalLocation
            FROM @t_ORDERS AS tor        
            JOIN #PICKDETAIL_WIP AS pw ON pw.Orderkey = tor.Orderkey
            JOIN dbo.LOC AS l WITH (NOLOCK) ON pw.Loc = l.Loc
            JOIN @t_OptimizeCZGroup_FC AS ocg ON ocg.CartonizationGroup = pw.CartonGroup        --(Wan03)
            WHERE tor.DocType = 'N'   
            AND pw.PackStation= 1
            AND pw.UOM IN ('2')       -- Full UCC For Same Orderkey
            AND pw.Orderkey = @c_Orderkey
            AND pw.CartonType = ''
            GROUP BY l.PickZone
                  ,  pw.SkuGroup
                  ,  l.LogicalLocation
                  ,  pw.DropID
                  ,  ocg.CartonType
                  ,  ocg.[Cube]
                  ,  ocg.MaxWeight 
           --HAVING SUM(pw.PickItemCube) <= ocg.[Cube] AND SUM(pw.PickItemWgt) <= ocg.MaxWeight          --(Wan10) 
           ORDER BY ROW_NUMBER() OVER (PARTITION BY pw.DropID ORDER BY ocg.[Cube], ocg.MaxWeight, ocg.CartonType) 
         ) d
      ) 
      UPDATE pw
         SET pw.LabelNo    = u.DropID
            ,pw.CartonType = u.CartonType
            ,pw.CartonSeqNo= u.SeqNo
            ,pw.CartonCube = ocg.[Cube]                                    --(Wan03)
      FROM #PICKDETAIL_WIP AS pw
      JOIN UCC_B2B AS u ON pw.DropID = u.DropID
      JOIN #OptimizeCZGroup AS ocg ON u.CartonType = ocg.CartonType        --(Wan03)

      ---------------------------------------------------------
      -- 1) For UCC to PackStation, UOM = '2' - END
      ---------------------------------------------------------
      ---------------------------------------------------------
      -- 2) For DP/DPP - Cartonization UOM IN ('6','7') - START
      ---------------------------------------------------------
      
      SET @n_CartonSeqNo = 0
      SELECT TOP 1 @n_CartonSeqNo = pw.CartonSeqNo
      FROM #PICKDETAIL_WIP AS pw
      WHERE pw.Orderkey = @c_Orderkey
      ORDER BY pw.CartonSeqNo DESC
      
      --(Wan13) - START
      SET @n_Status_FC = '9' 
      IF @c_FullSkuCarton = 'Y'  
      BEGIN  
         SET @n_Status_FC = '0'  
      END  
      --(Wan13) - END  

      SET @n_PackAccessQty = NULL
      SET @n_SplitToAccessQty = 0                                                --Wan02 
      WHILE 1 = 1
      BEGIN
         SELECT TOP 1
                 @c_PickZone = pw.PickZone   -- Mezzanine
               , @c_SkuGroup = pw.SkuGroup   -- Division
               --, @c_Style    = pw.Style                --(Wan08)
               --, @c_Size     = pw.Size 
               , @c_CartonGroup_B2B = pw.CartonGroup
               , @n_PackAccessQty   = CASE WHEN @n_PackAccessQty = 0 THEN @n_PackAccessQty ELSE pw.PackAccessQty END
         FROM #PICKDETAIL_WIP AS pw 
         WHERE pw.Orderkey = @c_Orderkey    
         AND pw.PackStation = 0
         AND pw.UOM IN ('6', '7')
         AND pw.CartonType = ''
         AND pw.SplitToAccessQty IN (0, @n_SplitToAccessQty)                     --Wan02 
         AND pw.Status_FC = @n_Status_FC                                         --Wan12
         AND EXISTS (SELECT 1 FROM #PICKDETAIL_WIP AS pw2
                     WHERE pw2.Orderkey = @c_Orderkey    
                     AND pw2.PackStation = 0
                     AND pw2.UOM IN ('6', '7')
                     AND pw2.CartonType = ''
                     AND pw2.PickZone = pw.PickZone
                     AND pw2.SkuGroup = pw.SkuGroup
                     AND pw2.Style = pw.Style
                     AND pw2.Sku = pw.Sku
                     AND pw2.SplitToAccessQty IN (0, @n_SplitToAccessQty)        --Wan02
                     AND pw.Status_FC = @n_Status_FC                             --Wan12                     
                     GROUP BY pw2.Sku   
                     HAVING SUM(CASE WHEN FLOOR(pw2.Qty/pw2.PackQtyIndicator) = 0 THEN 1    
                                     ELSE FLOOR(pw2.Qty/pw2.PackQtyIndicator)               
                                     END
                                 ) > CASE WHEN @n_PackAccessQty = 0 THEN @n_PackAccessQty ELSE pw.PackAccessQty END
                     )
         GROUP BY pw.PickZone   
               ,  pw.SkuGroup
               --,  pw.Style                             --(Wan08)
               --,  pw.Size 
               ,  pw.CartonGroup
               ,  pw.PackAccessQty
         ORDER BY pw.PickZone   
               ,  pw.SkuGroup  
               --,  pw.Style                             --(Wan08)
               --,  pw.Size
               , MIN(pw.Color)                           --(Wan08)
               , MIN(pw.[Size])                          --(Wan08)
               , MIN(pw.PickLogicalloc)                  --(Wan08)

         IF @@ROWCOUNT = 0 
         BEGIN
            IF @n_Status_FC = 0                                                  --Wan12 - START
            BEGIN
               SET @n_Status_FC = 9
               CONTINUE
            END                                                                  --Wan12 - END  
                                                                              
            IF @n_PackAccessQty = 0
            BEGIN
               BREAK
            END
            
            SET @n_PackAccessQty = 0
            SET @n_SplitToAccessQty = 1                                          --Wan02
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

            SET @b_1SkuFullCarton = 0                    --Wan12
            SET @b_ReduceToFit = 0                       --Wan12
                                                                  
            TRUNCATE TABLE #OptimizeItemToPack;
            
            --(Wan08) Filter by Pickzone, SkuGroup and Sort BY pw.Style, pw.Color, pw.Size, pw.PickLogicalloc                      
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
               --AND pw.Style     = @c_Style                                           --(Wan08)                                                                 
               AND pw.SplitToAccessQty IN (0, @n_SplitToAccessQty)                     --Wan02
               AND pw.Status_FC IN ( @n_Status_FC, '1' )                               --Wan12 
               AND EXISTS (SELECT 1 FROM #PICKDETAIL_WIP AS pw2
                           WHERE pw2.Orderkey = @c_Orderkey    
                           AND pw2.PackStation = 0
                           AND pw2.UOM IN ('6', '7')
                           AND pw2.CartonType = ''
                           AND pw2.PickZone = pw.PickZone
                           AND pw2.SkuGroup = pw.SkuGroup
                           AND pw2.Style = pw.Style
                           AND pw2.Sku = pw.Sku
                           AND pw2.SplitToAccessQty IN (0, @n_SplitToAccessQty)        --Wan02 
                           AND pw.Status_FC IN ( @n_Status_FC, '1' )                   --Wan12 
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
                        , Quantity = CASE WHEN a.RemainQtyWgt <= 0 OR a.RemainQtyCube <= 0         --Wan02
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
            
            SET @c_Sku_Optimize = ''                              --Wan12 - START
            IF @n_Status_FC = 0
            BEGIN
               SELECT TOP 1 @c_Sku_Optimize = oitp.SKU
               FROM #OptimizeItemToPack AS oitp 
               ORDER BY oitp.ID
               
               DELETE oitp
               FROM #OptimizeItemToPack AS oitp
               WHERE oitp.SKU <> @c_Sku_Optimize
               
               UPDATE pw
                  SET pw.Status_FC = 1
               FROM #PICKDETAIL_WIP AS pw
               JOIN #OptimizeItemToPack AS oitp ON oitp.RowRef = pw.RowRef
            END                                                    --Wan12 - END 
                                     
            --(Wan11) - START
            IF CHARINDEX(@c_SkuGroup, @c_SkuGroupSkipOptim, 1) > 0
            BEGIN
               IF @n_Status_FC = 0                                --Wan12 - START
               BEGIN
                  IF EXISTS (
                              SELECT 1 FROM #OptimizeItemToPack AS oitp 
                              JOIN #PICKDETAIL_WIP AS pw ON pw.RowRef = oitp.RowRef 
                              WHERE pw.Status_FC = 1                                                              --2022-10-05 Fixed
                              GROUP BY pw.StdCube, oitp.StdGrossWgt       
                              HAVING (SUM(pw.StdCube * oitp.Quantity) + pw.StdCube > @n_MaxCube_B2B OR
                                      SUM(oitp.StdGrossWgt * oitp.Quantity) + oitp.StdGrossWgt > @n_MaxWeight_B2B --2022-10-05 Fixed
                                     )
                  )
                  BEGIN
                     SET @b_1SkuFullCarton = 1
                  END
               END                                                
               ELSE
               BEGIN                                              --Wan12 END
                  -- Recalculate Carton that can fit in
                  SELECT TOP 1 @c_CartonType_B2B = ocg.CartonType  
                           ,@n_MaxCube_B2B    = ocg.[Cube]  
                           ,@n_MaxWeight_B2B  = ocg.MaxWeight  
                  FROM #OptimizeCZGroup AS ocg 
                  WHERE ocg.CartonizationGroup = @c_CartonGroup_B2B
                  AND EXISTS (SELECT 1 FROM #OptimizeItemToPack AS oitp 
                              JOIN #PICKDETAIL_WIP AS pw ON pw.RowRef = oitp.RowRef          --CR 3.0
                              HAVING SUM(pw.StdCube * oitp.Quantity) <= ocg.[Cube]           --CR 3.0
                              AND    SUM(oitp.StdGrossWgt * oitp.Quantity) <= ocg.MaxWeight) --CR 3.0
                  ORDER BY ocg.RowRef ASC 
               END                                                --Wan12
            END    
            ELSE
            BEGIN
               SET @b_MinQty1ToPack = 0
               SELECT TOP 1 @b_MinQty1ToPack = CASE WHEN oitp.SortID = 1 AND oitp.Quantity = 1 THEN 1 ELSE 0 END
               FROM #OptimizeItemToPack AS oitp
               ORDER BY oitp.SortID DESC
               
               --SET @n_CartonSeqNo = @n_CartonSeqNo + 1             --(Wan08)
               SET @c_CartonType_B2B_w = @c_CartonType_B2B
               SET @n_MaxCube_B2B_w = @n_MaxCube_B2B

               WHILE 1 = 1
               BEGIN 
                  --TRUNCATE TABLE @t_OptimizeResult;    --(Wan05) Change to use variable table
                  DELETE FROM @t_OptimizeResult;         --(Wan05) Change to use variable table
                  
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
                     SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing isp_SubmitToCartonizeAPI. (ispRLWAV43_PACK)'     
                                 + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '     
                     GOTO QUIT_SP    
                  END  
     
                  SET @c_IsCompletePack = ''  
                  SELECT @c_IsCompletePack = ore.IsCompletePack
                        ,@c_Sku_Optimize  = ore.Sku 
                        ,@n_Qty_Optimize  = ore.Qty
                  FROM @t_OptimizeResult AS ore 
                  
                  ------------------------------------------------
                  -- Cartonization Strategy for @n_Status_FC = 0
                  ------------------------------------------------
                  IF @n_Status_FC = 0 AND @c_IsCompletePack IN('TRUE')               --Wan12 - START
                  BEGIN 
                     IF @b_1SkuFullCarton = 1
                     BEGIN
                        SET @b_1SkuFullCarton = 0
                        BREAK
                     END
                     
                     SET @b_1SkuFullCarton = 1
                     
                     IF @b_ReduceToFit = 1
                     BEGIN
                        BREAK
                     END
                     --Add 1 Qty to check can fit another qty, If Fit mean not sku current qty does not fit full carton
                     INSERT INTO #OptimizeItemToPack
                         ( Storerkey, SKU, Dim1, Dim2, Dim3, Quantity, RowRef, OriginalQty, StdGrossWgt, SortID )
                     SELECT TOP 1 oitp.Storerkey, oitp.Sku, oitp.Dim1, oitp.Dim2, oitp.Dim3, 1, 0, 1, StdGrossWgt, SortID + 1
                     FROM #OptimizeItemToPack AS oitp
                     ORDER BY oitp.ID DESC 
                     
                     CONTINUE
                  END   
                  
                  SET @n_ID_ToUpd = 0
                  SET @n_SkuQty_ToPack = 0
                  IF @n_Status_FC = 0 AND @c_IsCompletePack IN('', 'FALSE')               
                  BEGIN 
                     IF @b_1SkuFullCarton = 1
                     BEGIN
                        BREAK
                     END
                     
                     SET @b_ReduceToFit = 1
                     SELECT TOP 1 
                           @n_ID_ToUpd = oitp.ID
                        ,  @n_SkuQty_ToPack = oitp.Quantity
                     FROM #OptimizeItemToPack AS oitp
                     ORDER BY oitp.ID DESC 
                     
                     IF @@ROWCOUNT = 0
                     BEGIN
                        BREAK
                     END
                  
                     IF @n_SkuQty_ToPack = 1
                     BEGIN
                        DELETE oitp FROM #OptimizeItemToPack AS oitp WHERE oitp.ID = @n_ID_ToUpd
                     END
                     ELSE
                     BEGIN
                        UPDATE oitp SET oitp.Quantity = oitp.Quantity - 1 
                        FROM #OptimizeItemToPack AS oitp 
                        WHERE oitp.ID = @n_ID_ToUpd
                     END   
                     CONTINUE
                  END                                                                   --Wan12 - END
                  ------------------------------------------------
                  -- Cartonization Strategy for @n_Status_FC = 9
                  ------------------------------------------------
                  IF @c_IsCompletePack IN('','FAIL') OR @c_CartonType_B2B_w = @c_CartonType_B2B       --(Wan08) Increse performance
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
                     
                     --(Wan08) - START
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
                     --(Wan08) - END
                  END                                                                                 --(Wan08) - Increase performance
                                    
                  IF @c_IsCompletePack = 'TRUE'    
                  BEGIN
                       --Access Qty = 2
                     --TO_pack = 8,  remain =  4, original = 12      -- Pack to current  
                     --TO_pack = 10, remain =  2, original = 12      -- pack to new -- know as it is fit
                     --to_pack = 2,  remain = 10, original = 12      -- pack to new
                     
                     SET @n_TotalToPack = 0                                                                 --(Wan08)
                     SELECT @n_TotalToPack = SUM(pw.Qty)                                                    --(Wan08) --(Wan06) - START
                     --FROM #OptimizeItemToPack AS oitp                                                     --(Wan08) 
                     FROM #PICKDETAIL_WIP AS pw                                                             --(Wan08)
                     WHERE pw.Orderkey = @c_Orderkey                                                        --(Wan08)
                     AND pw.PackStation = 0                                                                 --(Wan08)
                     AND pw.UOM IN ('6', '7')                                                               --(Wan08)
                     AND pw.CartonType = ''                                                                 --(Wan08)
                     AND pw.PickZone  = @c_PickZone                                                         --(Wan08)
                     AND pw.SkuGroup  = @c_SkuGroup                                                         --(Wan08)
                     AND pw.Sku = @c_Sku_ToPack                                                             --(Wan08)                                                                 
                     AND pw.SplitToAccessQty IN (0, @n_SplitToAccessQty)   
                     GROUP BY pw.Orderkey                                                                   --(Wan08)       
                     
                     SET @n_Qty_ToUpd = @n_Qty_ToPack                                                       --(Wan08)
                     SET @n_QtyRemain_ToPack = @n_TotalToPack - @n_Qty_ToPack                               --(Wan08)
                     
                     IF @n_SkuQty_ToPack > @n_Qty_ToPack       --@n_TotalToPack > @n_Qty_ToPack             --(Wan08)
                     BEGIN
                        --SET @n_Qty_ToPack = @n_TotalToPack                                                --(Wan08)
                        --SET @n_OrignalQty_ToPack = @n_Qty_ToPack                                          --(Wan08) 
                        SET @n_Qty_ToUpd = @n_SkuQty_ToPack                                                 --(Wan08)
                        SET @n_QtyRemain_ToPack = @n_TotalToPack - @n_SkuQty_ToPack                         --(Wan08) 
                     END                                                                                             --(Wan06)  - END
                     
                     --SET @n_Qty_ToUpd = @n_Qty_ToPack                                                     --(Wan08)
                     --SET @n_QtyRemain_ToPack = @n_OrignalQty_ToPack - @n_Qty_ToPack                       --(Wan08)
                     
                     IF @n_Qty_ToUpd <= @n_PackAccessQty
                     BEGIN
                        SET @n_Qty_ToUpd = 0
                     END
                     
                     IF @n_QtyRemain_ToPack > 0 AND @n_QtyRemain_ToPack <= @n_PackAccessQty 
                     BEGIN
                        SET @n_Qty_ToUpd = 0
                     END
                     
                     --(Wan08) - START
                     --Not to reduce qty if @n_Qty_ToUpd > 0,        
                     --if @n_Qty_ToPack use to calc qty_toupd if @n_QtyRemain_ToPack <= @n_PackAccessQty
                     IF @n_Qty_ToUpd > 0  
                     BEGIN                  
                        SET @n_Qty_ToPack = @n_Qty_ToUpd
                     END
                     --(Wan08) - START
                  END
                  ELSE
                  BEGIN         
                     IF @c_CartonType_B2B_w <> @c_CartonType_B2B -- If Not Large Carton and it is not able to fit into current cartontype, use previous fit cartontype
                     BEGIN
                        --SET @c_CartonType_B2B = @c_CartonType_B2B_w  --@c_CartonType_B2B_New
                        --SET @n_MaxCube_B2B = @n_MaxCube_B2B_w     --@n_MaxCube_B2B_New
                        BREAK
                     END
                  
                     --Wan02 
                     --IF @b_MinQty1ToPack = 1 -- pack at least 1 qty to Large Carton even if 0 qty to fit to Large box
                     --BEGIN
                     --   BREAK
                     --END
                                   
                     IF @c_IsCompletePack = ''-- Sku's LxWxH > Carton's LxWxH, prompt error 
                     OR @b_MinQty1ToPack = 1  -- Prompt Error if Qty 1 cannot fit in
                     BEGIN
                        SET @n_Continue = 3
                        SET @n_Err = 64015
                        SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Sku: ' + RTRIM(@c_Sku_ToPack)+ ' cannot fit into Carton. (ispRLWAV43_PACK)'     
                                 + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '     
                        GOTO QUIT_SP   
                     END
                     
                     --Access Qty = 2
                     --TO_pack = 8,  remain =  4, original = 12      -- Pack to current  
                     --TO_pack = 10, remain =  2, original = 12      -- pack to new --does not know as not send to API
                     --to_pack = 2,  remain = 10, original = 12      -- pack to new
                     
                     -- Reduce By 1 if cannot fit into Large Carton
                     --SET @n_Qty_ToUpd = @n_Qty_ToPack - 1          --(Wan08)  
                     SET @n_QtyRemain_ToPack = 0                   
       
                     SET @n_Qty_ToUpd = @n_SkuQty_ToPack - 1         --(Wan08)    
                     
                     --Notes: @n_Qty_ToPack < @n_SkuQty_ToPack < @n_PackAccessQty
                     IF @n_Qty_ToUpd <= @n_PackAccessQty             --Comparing Total Qty of Sku against PackAccessQty, 
                     BEGIN
                        SET @n_Qty_ToUpd = 0
                     END
                     --(Wan08) - START
                     ELSE
                     BEGIN
                        SET @n_Qty_ToUpd = @n_Qty_ToPack - 1         --Reducing qty for Last record of sku
                     END
                     --(Wan08) - END
                  END

                  IF @n_Qty_ToUpd = 0     --Delete current to pack to new carton, need to check able to delete before execute               
                  BEGIN
                     --(Wan08) - START
                     SELECT @n_ItemToPackCnt = COUNT(1) 
                     FROM #OptimizeItemToPack AS oitp 

                     SET @n_ItemToPackCnt = @n_ItemToPackCnt - @n_SkuItemToPackCnt 
                     
                     --(Wan09) - START
                     --Check to Handle multi record with 1 unique sku fail to send API 
                     SET @b_RemoveLastRecord = 0
                     IF @n_ItemToPackCnt = 0 AND @n_Qty_ToPack < @n_SkuQty_ToPack
                     BEGIN
                        SET @n_ItemToPackCnt = @n_SkuItemToPackCnt - 1
                        SET @b_RemoveLastRecord = 1
                     END
                     --(Wan09) - END

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
                        --(Wan09) - START
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
                        --(Wan09) - END
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
                  
                  /*
                     SET @n_ItemToPackCnt = 0
                     SELECT @n_ItemToPackCnt = COUNT(1) 
                     FROM #OptimizeItemToPack AS oitp
                     
                     IF @n_ItemToPackCnt > 1      -- The Only ItemToPack record Left by reducing Qty_ToPack
                     BEGIN 
                        DELETE oitp             -- delete last record and submit API to check 
                        FROM #OptimizeItemToPack AS oitp
                        WHERE oitp.ID = @n_ID_ToPack 
                     
                        CONTINUE 
                     END
                        
                     --Access qty  =2, TRUE
                     -- TRUE: to_pack = 1, remain = 11, original = 12  to_Pack = 1  and split 11, repeat until 11 qty split and 1 qty pack to 1 carton
                     -- to_pack = 11, remain = 1, original = 12, then to_pack = 10  and split 10 and 2 with no carton type, take 10 to submit API, pack 10
                     
                     SET @n_Qty_ToUpd = CASE WHEN @n_PackAccessQty = 0 THEN 1                                           --To Pack 1 Qty if 0 qty to fit 
                                             WHEN @n_Qty_ToPack <= @n_PackAccessQty THEN @n_Qty_ToPack                  --To avaoid update qty more than Original Qty                  
                                             WHEN @n_OrignalQty_ToPack <= @n_PackAccessQty THEN @n_OrignalQty_ToPack    --To avaoid update qty more than Original Qty
                                             WHEN @n_QtyRemain_ToPack > 0 AND @n_QtyRemain_ToPack <= @n_PackAccessQty THEN @n_OrignalQty_ToPack - @n_PackAccessQty
                                             ELSE @n_PackAccessQty 
                                             END
                                        
                     IF @n_PackAccessQty = 0 AND @n_Qty_ToUpd = 1 -- Force to pack 1 Qty into a carton, continue to recalculate the cartontype after update qty to pack
                     BEGIN
                        SET @b_MinQty1ToPack = 1
                     END
                     ELSE
                     BEGIN  
                        IF @n_Qty_ToUpd <> @n_Qty_ToPack AND @n_Qty_ToUpd <= @n_PackAccessQty
                        BEGIN 
                           SET @c_CartonType_B2B = ''
                           SET @n_CartonSeqNo = @n_CartonSeqNo - 1
                        END
                        --(Wan05) - START 
                        ELSE IF @n_Qty_ToUpd <= @n_PackAccessQty AND @n_PackAccessQty > 0 
                        BEGIN
                           UPDATE pw                                    --(Wan06)
                              SET pw.SplitToAccessQty = 1                
                           FROM #OptimizeItemToPack AS oitp
                           JOIN #PICKDETAIL_WIP AS pw ON pw.RowRef = oitp.RowRef
                           
                           -- delete last record and submit API to check & 
                           DELETE oitp                
                           FROM #OptimizeItemToPack AS oitp  
                           WHERE oitp.ID = @n_ID_ToPack 
                           
                           --SET @n_PackAccessQty = 0                   --(Wan06)
                           --SET @n_SplitToAccessQty = 1                --(Wan06)
                           SET @n_CartonSeqNo = @n_CartonSeqNo - 1      --(Wan06)

                           BREAK
                        END
                        --(Wan05) - END
                     END
                  END
                  */
                  --(Wan08) - END

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
            END   --(Wan11) - END
            --(Wan08) - START
            
            IF @n_Status_FC = 0 AND @b_1SkuFullCarton = 0                                     --Wan12 - START
            BEGIN 
               UPDATE #PICKDETAIL_WIP SET Status_FC = 9
               WHERE Status_FC = 1
               BREAK
            END                                                                               --Wan12 - END
            
            IF NOT EXISTS ( SELECT 1 FROM #OptimizeItemToPack AS oitp)  
            BEGIN
               BREAK
            END 

            IF @c_CartonType_B2B <> ''
            BEGIN
               SET @n_CartonSeqNo = @n_CartonSeqNo + 1     
            END
            --(Wan08) - END
            
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
                  ,  Status_FC                                 --(Wan12)                        
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
                  ,  Status_FC = @n_Status_FC                  --(Wan12)
               FROM #OptimizeItemToPack AS oitp
               JOIN #PICKDETAIL_WIP AS pw ON pw.RowRef = oitp.RowRef        
               WHERE pw.Qty > oitp.Quantity
            END   
            
            --Wan02 - Update if c_CartonType_B2B = '' 
            --IF @c_CartonType_B2B <> ''
            --BEGIN         
               UPDATE pw
                  SET pw.CartonType   = CASE WHEN @c_CartonType_B2B <> '' THEN @c_CartonType_B2B ELSE pw.CartonType END
                     , pw.CartonSeqNo = CASE WHEN @c_CartonType_B2B <> '' THEN @n_CartonSeqNo ELSE pw.CartonSeqNo END
                     , pw.CartonCube  = CASE WHEN @c_CartonType_B2B <> '' THEN @n_MaxCube_B2B ELSE pw.CartonCube END
                     , pw.Qty = oitp.Quantity
                     , pw.PickItemCube = oitp.Quantity * pw.StdCube
                     , pw.PickItemWgt  = oitp.Quantity * pw.StdGrossWgt
                     , pw.Status_CZ = CASE WHEN pw.Qty > oitp.Quantity AND pw.Status_CZ = 0 THEN 1 ELSE pw.Status_CZ END--If Split record, remain status_CZ = 2
                     , pw.SplitToAccessQty = CASE WHEN @n_Status_FC = 0 THEN pw.SplitToAccessQty         --Wan12
                                                  WHEN @c_CartonType_B2B = '' THEN 1 ELSE 0 END 
                     , pw.Status_FC = 9                                                                  --Wan12                
               FROM #OptimizeItemToPack AS oitp
               JOIN #PICKDETAIL_WIP AS pw ON pw.RowRef = oitp.RowRef
            --END
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
      
      --(Wan03) 
      SET @n_RecCnt = 0
      SET @c_Sku = ''
      SELECT TOP 1 
               @n_RecCnt = 1
             , @c_Sku = RTRIM(pw.Sku)
      FROM #PICKDETAIL_WIP AS pw 
      WHERE pw.Orderkey = @c_Orderkey AND pw.CartonType = ''
      ORDER BY pw.RowRef
            
      --IF EXISTS (SELECT 1 FROM #PICKDETAIL_WIP AS pw WHERE pw.Orderkey = @c_Orderkey AND pw.CartonType = '')
      IF @n_RecCnt = 1
      BEGIN
         SET @n_continue = 3  
         SET @n_Err = 64020
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Shipment Order without carton type found, Orderkey: ' + @c_Orderkey + ', Sku: ' + @c_Sku
                      + '. (ispRLWAV43_PACK)' 
         GOTO QUIT_SP      
      END
      
      ------------------------------------------
      --- Create PACK  - START
      ------------------------------------------
      SET @c_PickSlipNo = ''
      SELECT @c_PickSlipNo = p.PickHeaderKey
      FROM dbo.PICKHEADER AS p  WITH (NOLOCK)
      WHERE p.Orderkey = @c_Orderkey
      AND   p.ExternOrderkey = @c_Loadkey
      AND   p.[Zone] = '3'

      IF @c_PickSlipNo = ''
      BEGIN
         SET @b_success = 1  
         EXECUTE nspg_getkey  
               'PickSlip'  
               , 9  
               , @c_PickSlipNo   OUTPUT  
               , @b_success      OUTPUT  
               , @n_err          OUTPUT  
               , @c_errmsg       OUTPUT
                 
         IF NOT @b_success = 1  
         BEGIN  
            SET @n_continue = 3
            GOTO QUIT_SP  
         END  
 
         SET @c_Pickslipno = 'P' + @c_Pickslipno

         INSERT INTO dbo.PICKHEADER (PickHeaderKey, ExternOrderKey, Orderkey, PickType, Zone, Loadkey, Wavekey, Storerkey) 
         VALUES (@c_Pickslipno , @c_LoadKey, @c_Orderkey, '0', '3', @c_Loadkey, @c_Wavekey, @c_Storerkey)       
               
         SET @n_err = @@ERROR  
         IF @n_err <> 0  
         BEGIN
            SET @n_continue = 3  
            SET @n_Err = 64030
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKHEADER Failed. (ispRLWAV43_PACK)' 
            GOTO QUIT_SP
         END   

         INSERT INTO dbo.PickingInfo (PickSlipNo, ScanInDate, PickerID, ScanOutDate)  
         VALUES (@c_Pickslipno , NULL, NULL, NULL) 

         SET @n_err = @@ERROR  
         IF @n_err <> 0  
         BEGIN
            SET @n_continue = 3  
            SET @n_Err = 64040 
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKINGINFO Failed. (ispRLWAV43_PACK)' 
            GOTO QUIT_SP
         END   
      END

      IF @c_DocType = 'N'
      BEGIN        
         IF NOT EXISTS (SELECT 1 FROM PACKHEADER PH WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo)
         BEGIN
            INSERT INTO PACKHEADER (PickSlipNo, Storerkey, Orderkey, Loadkey, Consigneekey, [Route], OrderRefNo )  
            VALUES (@c_Pickslipno , @c_Storerkey, @c_Orderkey, @c_Loadkey, @c_Consigneekey, @c_Route, @c_ExternOrderkey)  

            SET @n_err = @@ERROR  
            IF @n_err <> 0  
            BEGIN
               SET @n_continue = 3  
               SET @n_Err = 64050 
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PACKHEADER Failed. (ispRLWAV43_PACK)' 
               GOTO QUIT_SP
            END         
         END
      END
      
      -------------------------------------------------------
      -- Gen Label#,Stamp CaseID, PickSlipNo
      -- and Split PickDetail - START
      -------------------------------------------------------
      SET @n_CartonSeqNo = 0
      WHILE 1 = 1
      BEGIN
         SET @c_LabelNo = ''
         SELECT TOP 1 @n_CartonSeqNo = pw.CartonSeqNo
                  ,  @c_LabelNo = pw.LabelNo
         FROM #PICKDETAIL_WIP AS pw
         WHERE pw.Orderkey = @c_Orderkey
         AND pw.CartonType <> ''
         AND pw.CartonSeqNo > @n_CartonSeqNo
         ORDER BY pw.CartonSeqNo
         
         IF @@ROWCOUNT = 0
         BEGIN
            BREAK
         END
         
         IF @n_debug = 1
         BEGIN
            PRINT '@c_LabelNo: ' + @c_LabelNo 
                +',@c_Orderkey: ' + @c_Orderkey
         END 
         
         IF @c_LabelNo = ''
         BEGIN
            EXEC isp_GenUCCLabelNo_Std    
                  @cPickslipNo   = @c_PickSlipNo  
               ,  @nCartonNo     = 0  
               ,  @cLabelNo      = @c_LabelNo   OUTPUT  
               ,  @b_success     = @b_success   OUTPUT  
               ,  @n_err         = @n_err       OUTPUT  
               ,  @c_errmsg      = @c_errmsg    OUTPUT  
  
            IF @b_Success <> 1  
            BEGIN  
               SET @n_continue = 3  
               SET @n_err = 64060   
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing isp_GenUCCLabelNo_Std. (ispRLWAV43_PACK)'   
                              + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '   
               GOTO QUIT_SP 
            END  
         END  
         
         SET @CUR_PD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT pw.PickDetailKey
               ,pw.Qty
               ,pw.[Status_CZ]
         FROM #PICKDETAIL_WIP AS pw
         WHERE pw.Orderkey = @c_Orderkey
         AND   pw.CartonSeqNo = @n_CartonSeqNo
         ORDER BY pw.CartonSeqNo
               ,  pw.PickDetailKey
               ,  pw.RowRef

         OPEN @CUR_PD
   
         FETCH NEXT FROM @CUR_PD INTO @c_PickDetailKey
                                   ,  @n_Qty
                                   ,  @n_Status
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            IF @n_Status = 2
            BEGIN
               SET @b_success = 1  
               EXECUTE nspg_getkey  
                     'Pickdetailkey'  
                     , 10  
                     , @c_NewPickDetailKey   OUTPUT  
                     , @b_success            OUTPUT  
                     , @n_err                OUTPUT  
                     , @c_errmsg             OUTPUT
                 
               IF NOT @b_success = 1  
               BEGIN  
                  SET @n_continue = 3
                  GOTO QUIT_SP  
               END  

               INSERT INTO PICKDETAIL 
                     (  PickDetailKey
                     ,  CaseID
                     ,  PickHeaderKey
                     ,  OrderKey
                     ,  OrderLineNumber
                     ,  Lot
                     ,  Storerkey
                     ,  Sku
                     ,  AltSku
                     ,  UOM
                     ,  UOMQty
                     ,  Qty
                     ,  QtyMoved
                     ,  [Status]
                     ,  DropID
                     ,  Loc
                     ,  ID
                     ,  PackKey
                     ,  UpdateSource
                     ,  CartonGroup
                     ,  CartonType
                     ,  ToLoc
                     ,  DoReplenish
                     ,  ReplenishZone
                     ,  DoCartonize
                     ,  PickMethod
                     ,  WaveKey
                     ,  EffectiveDate
                     ,  OptimizeCop
                     ,  ShipFlag
                     ,  PickSlipNo
                     ,  Taskdetailkey
                     ,  TaskManagerReasonkey
                     ,  Notes 
                     ,  Channel_ID              --(Wan04) - Spilt Pickdetail to include Channel_ID 
                     )
               SELECT PickDetailKey = @c_NewPickDetailKey
                    , CaseID = @c_LabelNo
                    , p.PickHeaderKey
                    , p.OrderKey
                    , p.OrderLineNumber
                    , p.Lot
                    , p.Storerkey
                    , p.Sku
                    , p.AltSku
                    , p.UOM
                    , p.UOMQty 
                    , Qty    = @n_Qty
                    , p.QtyMoved
                    , p.[Status]
                    , p.DropID
                    , p.Loc
                    , p.ID
                    , p.PackKey
                    , p.UpdateSource
                    , p.CartonGroup
                    , p.CartonType
                    , p.ToLoc
                    , p.DoReplenish
                    , p.ReplenishZone
                    , p.DoCartonize
                    , p.PickMethod
                    , p.WaveKey
                    , p.EffectiveDate
                    , OptimizeCop = '9'
                    , p.ShipFlag
                    , PickSlipNo = CASE WHEN @c_DocType = 'N' THEN @c_PickSlipNo ELSE p.PickSlipNo END 
                    , p.Taskdetailkey
                    , p.TaskManagerReasonkey
                    , @c_PickDetailKey + ', Originalqty = ' + CAST(p.Qty + @n_Qty AS VARCHAR) 
                    , p.Channel_ID              --(Wan04) - Spilt Pickdetail to include Channel_ID       
               FROM dbo.PICKDETAIL AS p WITH (NOLOCK) 
               WHERE p.PickDetailKey = @c_PickDetailKey

               SET @n_err = @@ERROR  
               IF @n_err <> 0  
               BEGIN
                  SET @n_continue = 3  
                  SET @n_Err = 64070
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKDETAIL Failed. (ispRLWAV43_PACK)' 
                  GOTO QUIT_SP
               END 
            END
            ELSE
            BEGIN
               UPDATE p WITH (ROWLOCK)
                  SET p.CaseID = @c_LabelNo
                     ,p.Qty    = CASE WHEN @n_Status = 0 THEN p.Qty ELSE @n_Qty END
                     ,p.PickSlipNo = CASE WHEN @c_DocType = 'N' THEN @c_PickSlipNo ELSE p.PickSlipNo END
                     ,p.Trafficcop = NULL
                     ,p.EditWho    = SUSER_SNAME()
                     ,p.EditDate   = GETDATE()
               FROM dbo.PICKDETAIL AS p
               WHERE p.PickDetailKey = @c_PickDetailkey

               SET @n_err = @@ERROR  
               IF @n_err <> 0  
               BEGIN
                  SET @n_continue = 3  
                  SET @n_Err = 64080
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update PICKDETAIL Failed. (ispRLWAV43_PACK)' 
                  GOTO QUIT_SP
               END 
            END
         
            FETCH NEXT FROM @CUR_PD INTO @c_PickDetailKey
                                       , @n_Qty
                                       , @n_Status
         END
         CLOSE @CUR_PD
         DEALLOCATE @CUR_PD
         
         IF @c_DocType = 'N'
         BEGIN
            UPDATE pw
            SET pw.LabelNo = @c_labelNo
               ,pw.PickSlipNo = @c_PickSlipNo
            FROM #PICKDETAIL_WIP AS pw      
            WHERE pw.Orderkey = @c_Orderkey
            AND CartonSeqNo = @n_CartonSeqNo
         END
      END
      -----------------------------------------------------
      -- Gen Label#,Stamp CaseID and Split PickDetail - END
      -----------------------------------------------------
      IF @c_DocType = 'N'
      BEGIN
         IF EXISTS (SELECT 1 FROM dbo.PackDetail AS pd WITH (NOLOCK) WHERE pd.PickSlipNo = @c_PickSlipNo)
         BEGIN
            --Re-Cartonization Again If Packdetail exists
            ---------------------------------------------------
            -- Delete PackDetail
            ---------------------------------------------------
            ;WITH delp ( PickSlipNo, CartonNo ) AS 
            (  SELECT  pd.PickSlipNo
                     , pd.CartonNo
               FROM dbo.PackDetail AS pd WITH (NOLOCK)
               WHERE pd.PickSlipNo = @c_PickSlipNo
            )
         
            DELETE pd WITH (ROWLOCK)
            FROM dbo.PackDetail AS pd
            JOIN delp AS d ON  d.PickSlipNo = pd.PickSlipNo
                           AND d.CartonNo = pd.CartonNo 

            SET @n_err = @@ERROR  
            IF @n_err <> 0  
            BEGIN
               SET @n_continue = 3  
               SET @n_Err = 64090 
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete PACKDETAIL Failed. (ispRLWAV43_PACK)' 
               GOTO QUIT_SP
            END  
         END

         IF @n_debug = 1
         BEGIN
            SELECT @c_PickSlipNo
                  ,CartonNo = PD.CartonSeqNo --+ @n_CartonNo
                  ,[Weight] = ISNULL(SUM(PD.StdGrossWgt * PD.Qty),0.00)
                  ,[Cube]   = PD.CartonCube                              
                  ,Qty = ISNULL(SUM(PD.Qty),0)
                  ,PD.CartonType
            FROM #PICKDETAIL_WIP PD
            WHERE PD.Orderkey = @c_Orderkey
            GROUP BY PD.CartonSeqNo
                  ,  PD.CartonType
                  ,  PD.CartonCube                                     
            
            SELECT @c_PickSlipNo
                  ,CartonNo = PD.CartonSeqNo 
                  ,PD.LabelNo
                  ,LabelLine = RIGHT('00000' + CONVERT(NVARCHAR(5), ROW_NUMBER() OVER (PARTITION BY PD.LabelNo ORDER BY PD.CartonSeqNo, PD.Storerkey, PD.Sku)),5)
                  ,PD.Storerkey
                  ,PD.Sku
                  ,Qty = ISNULL(SUM(Qty),0)
            FROM #PICKDETAIL_WIP PD
            WHERE PD.Orderkey = @c_Orderkey
            GROUP BY PD.CartonSeqNo
                  ,  PD.LabelNo
                  ,  PD.Storerkey
                  ,  PD.Sku
               
            SELECT @c_PickSlipNo
                  ,CartonNo = PD.CartonSeqNo --+ @n_CartonNo
                  ,PD.LabelNo
                  ,PD.Storerkey
                  ,PD.Sku
                  ,PD.Qty
                  , Cartontype,cartonseqno
                  , status_cz
            FROM #PICKDETAIL_WIP PD
            WHERE PD.Orderkey = @c_Orderkey  
            ORDER BY CartonSeqNo    
         END
                      
         INSERT INTO dbo.PackDetail
            (  PickSlipNo
            ,  CartonNo
            ,  LabelNo
            ,  LabelLine
            ,  Storerkey
            ,  Sku
            ,  Qty
            )
         SELECT @c_PickSlipNo
               ,CartonNo = pw.CartonSeqNo 
               ,pw.LabelNo
               ,LabelLine = RIGHT('00000' + CONVERT(NVARCHAR(5), ROW_NUMBER() 
                            OVER (PARTITION BY pw.LabelNo ORDER BY pw.CartonSeqNo, pw.Storerkey, pw.Sku)),5)
               ,pw.Storerkey
               ,pw.Sku
               ,Qty = ISNULL(SUM(Qty),0)
         FROM #PICKDETAIL_WIP AS pw
         WHERE pw.Orderkey = @c_Orderkey
         GROUP BY pw.CartonSeqNo
               ,  pw.LabelNo
               ,  pw.Storerkey
               ,  pw.Sku

         SET @n_err = @@ERROR  
         IF @n_err <> 0  
         BEGIN
            SET @n_continue = 3  
            SET @n_Err = 64100 
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PACKDETAIL Failed. (ispRLWAV43_PACK)' 
            GOTO QUIT_SP
         END 

         
         INSERT INTO dbo.PackInfo
            (  PickSlipNo
            ,  CartonNo
            ,  [Weight]
            ,  [Cube]
            ,  Qty
            ,  CartonType
            )
         SELECT @c_PickSlipNo
               ,CartonNo = pw.CartonSeqNo 
               ,[Weight] = ISNULL(SUM(pw.StdGrossWgt * pw.Qty),0.00)
               ,[Cube]   = pw.CartonCube                             
               ,Qty = ISNULL(SUM(pw.Qty),0)
               ,pw.CartonType
         FROM #PICKDETAIL_WIP AS pw
         WHERE pw.Orderkey = @c_Orderkey
         GROUP BY pw.CartonSeqNo
               ,  pw.CartonType
               ,  pw.CartonCube                                     
 
         SET @n_err = @@ERROR  
         IF @n_err <> 0  
         BEGIN
            SET @n_continue = 3  
            SET @n_Err = 64100 
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PACKINFO Failed. (ispRLWAV43_PACK)' 
            GOTO QUIT_SP
         END 
         ------------------------------------------
         --- Create PACK  - END
         ------------------------------------------
      END
      FETCH NEXT FROM @CUR_ORD INTO @c_Orderkey
                                 ,  @c_Loadkey
                                 ,  @c_Route
                                 ,  @c_ExternOrderkey
                                 ,  @c_DocType
   END
   CLOSE @CUR_ORD
   DEALLOCATE @CUR_ORD  

QUIT_SP:
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispRLWAV43_PACK'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO