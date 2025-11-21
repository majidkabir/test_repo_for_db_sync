SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: ispBatPA02                                              */
/* Creation Date: 30-OCT-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-6707 - [CN] NIKE CRW Putaway Strategy                   */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.5                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2018-12-12  Wan01    1.2   Commit Sku to avoid data blocking         */
/* 2018-12-14  Wan02    1.2   Performance Tune                          */
/* 2018-12-18  Wan03    1.2   Fixed getting same receiptlinenumber      */
/* 2018-12-19  Wan04    1.3   Fixed to LOOKUP LOT using LA Instead get  */
/*                            from ITRN due to ITRN had been archive    */   
/* 2019-01-07  Wan05    1.4   Performance Trace                         */
/* 2019-01-08  Wan06    1.4   Performance tune                          */
/* 2019-03-15  Wan07    1.5   WMS-8318-[CN] NIKE 1M1C Putaway StrategyCR*/
/* 2019-04-02  Wan08    1.6   Fixed to check Sku & material. if no      */
/*                            inventory, get the most empty loc         */
/* 2019-05-28  WLChooi  1.7   WMS-9180 - Split line by each qty & Fix   */
/*                            Freeseat issue (WL01)                     */
/************************************************************************/
CREATE PROC [dbo].[ispBatPA02]
           @c_ReceiptKey     NVARCHAR(10)
         , @b_Success        INT            OUTPUT
         , @n_Err            INT            OUTPUT
         , @c_ErrMsg         NVARCHAR(2000) OUTPUT
         , @b_debug          INT = 0 
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt          INT
         , @n_Continue           INT 

         , @c_Facility           NVARCHAR(5)    = ''
         , @c_Site               NVARCHAR(30)   = ''
         , @c_PADone             NVARCHAR(30)   = ''
         , @c_SuggestLoc         NVARCHAR(10)   = ''
         , @c_PutawayZone        NVARCHAR(10)   = ''
         , @c_PickZone           NVARCHAR(10)   = ''
         , @c_LocationCategory   NVARCHAR(10)   = ''

         , @c_SourceKey          NVARCHAR(15)   = ''
         , @c_ReceiptLineNumber  NVARCHAR(5)    = ''
         , @c_Storerkey          NVARCHAR(15)   = ''
         , @c_Sku                NVARCHAR(20)   = ''
         , @c_SkuGroup           NVARCHAR(10)   = ''
         , @c_ItemClass          NVARCHAR(10)   = ''
         , @c_FromLot            NVARCHAR(10)   = ''
         , @c_FromLoc            NVARCHAR(10)   = ''
         , @c_FromID             NVARCHAR(18)   = ''
         , @c_HBLoc              NVARCHAR(10)   = ''

         , @c_ReceiptLineUpdate  NVARCHAR(5)    = ''
         , @n_PAInsertQty        INT            = 0

         , @n_SkuQtyReceived     INT            = 0
         , @n_SkuQtyRemaining    INT            = 0
         , @n_QtyConv            INT            = 0
         , @n_Strategy           INT            = 0
         , @n_LocAvailQTY        INT            = 0
         , @n_QtyReceived        INT            = 0
         , @n_LinePAQty          INT            = 0
         , @n_PAToLocQty         INT            = 0

         , @c_Lottable01         NVARCHAR(18)   = ''        --(Wan04)
         , @c_Lottable02         NVARCHAR(18)   = ''        --(Wan04)
         , @c_Lottable03         NVARCHAR(18)   = ''        --(Wan04)
         , @d_Lottable04         DATETIME       = NULL      --(Wan04)   
         , @d_Lottable05         DATETIME       = NULL      --(Wan04)
         , @c_Lottable06         NVARCHAR(30)   = ''        --(Wan04)                
         , @c_Lottable07         NVARCHAR(30)   = ''        --(Wan04)                 
         , @c_Lottable08         NVARCHAR(30)   = ''        --(Wan04)               
         , @c_Lottable09         NVARCHAR(30)   = ''        --(Wan04)              
         , @c_Lottable10         NVARCHAR(30)   = ''        --(Wan04)               
         , @c_Lottable11         NVARCHAR(30)   = ''        --(Wan04)               
         , @c_Lottable12         NVARCHAR(30)   = ''        --(Wan04)              
         , @d_Lottable13         DATETIME       = NULL      --(Wan04)              
         , @d_Lottable14         DATETIME       = NULL      --(Wan04)              
         , @d_Lottable15         DATETIME       = NULL      --(Wan04)  
         

         , @n_PABookingKey       INT            = 0

         , @n_Cnt                INT            = 1
         , @n_SkuGrpPKValue      INT            = 0   
         , @n_PKCRWP_MZB         INT            = 0   
         , @n_PKCRW_MZB          INT            = 0   
         , @n_PKCRWP_MZS         INT            = 0   
         , @n_PKCRW_MZS          INT            = 0   
         , @n_PKCRWP_HB          INT            = 0   
         , @n_PKCRW_HB           INT            = 0   

         , @n_SkuPKValue         INT            = 0 
         , @n_SkuPKValueMZB      INT            = 0 
         , @n_SkuPKValueMZS      INT            = 0      
         , @n_SkuPKValueHB       INT            = 0      

         , @n_PickZoneCnt        INT            = 0
         , @c_StrategyType       NVARCHAR(10)   = ''
         , @c_SkuWarningMsg      NVARCHAR(255)  = ''
         , @c_MaterialWarningMsg NVARCHAR(255)  = ''

         , @c_UserName           NVARCHAR(18)   = ''

         , @CUR_RDSKU            CURSOR
         
         , @d_ASNDateStart       DATETIME       = GETDATE()         
         , @d_ASNDateEnd         DATETIME       = NULL
            
         , @d_SkuDateStart       DATETIME       = NULL
         , @d_SkuDateEnd         DATETIME       = NULL         
         
         , @d_DateStart          DATETIME       = NULL
         , @d_DateEnd            DATETIME       = NULL
         
         , @c_Step1              NVARCHAR(10)   = ''
         , @c_Step2              NVARCHAR(10)   = ''
         , @c_Step3              NVARCHAR(10)   = ''
         , @c_Step4              NVARCHAR(10)   = ''
         , @c_Step5              NVARCHAR(10)   = ''    
         , @c_Step6              NVARCHAR(10)   = ''
         , @c_Step7              NVARCHAR(10)   = ''
         , @c_Step8              NVARCHAR(10)   = ''
         , @c_Step9              NVARCHAR(10)   = ''
         , @c_Step10             NVARCHAR(10)   = ''   
         
         , @n_NoOfMZ             INT            = 0
         , @n_QtyMZ2Process      INT            = 0
         , @n_QtyRemaining2MZ    INT            = 0  

         , @n_LoopCount          INT            = 0 --WL01

   --DECLARE @t_PICKZONE TABLE 
   CREATE TABLE #t_PICKZONE
            (  RowID          INT      IDENTITY(1,1)  PRIMARY KEY
            ,  Sku            NVARCHAR(20)   
            ,  StrategyType   NVARCHAR(10)   
            ,  PickZone       NVARCHAR(10) 
            ,  Loc            NVARCHAR(10)  
            ,  MZBAvailQTY    INT
            ,  MZSAvailQTY    INT
            ,  SKUMZBAvailQTY INT         DEFAULT (0) 
            ,  SKUMZSAvailQTY INT         DEFAULT (0)            
            )
   CREATE INDEX IDX_PZ ON #t_PICKZONE (PickZone)                     --(Wan02) 

   --DECLARE @t_PICKZONESUMM TABLE 
   CREATE TABLE #t_PICKZONESUMM
            (  RowID          INT      IDENTITY(1,1)  PRIMARY KEY
            ,  Sku            NVARCHAR(20)   
            ,  StrategyType   NVARCHAR(10)   
            ,  PickZone       NVARCHAR(10)   
            ,  MZBAvailQTY    INT
            ,  MZSAvailQTY    INT
            ,  LocAvailQTY    INT
            ,  PZPriority     INT
            )

   --(Wan06) - START
   CREATE TABLE #t_MSKU
            (  Storerkey      NVARCHAR(15)   NOT NULL
            ,  Sku            NVARCHAR(20)   NOT NULL
            ,  ItemClass      NVARCHAR(20)   NOT NULL
            ,  MSku           NVARCHAR(20)   NOT NULL
   PRIMARY KEY CLUSTERED (Storerkey, Sku, ItemClass, MSku)
            )

   CREATE TABLE #t_ZONE
            (  PickZone       NVARCHAR(10)   NOT NULL PRIMARY KEY
            )
   --(Wan06) - END

   --(Wan02) - START
   CREATE TABLE #T_LOC_HB
            (  Loc               NVARCHAR(10)   PRIMARY KEY
            ,  LogicalLocation   NVARCHAR(18)
            ,  PALogicalLoc      NVARCHAR(10)
            ,  Facility          NVARCHAR(5)
            ,  PutawayZone       NVARCHAR(10)   
            ,  LocationCategory  NVARCHAR(10)               
            ,  PickZone          NVARCHAR(10)   
            )            
   CREATE INDEX IDX_HB ON #T_LOC_HB (Facility, PutawayZone, LocationCategory, PickZone)     

   CREATE TABLE #T_LOC_MZ
            (  Loc               NVARCHAR(10)   PRIMARY KEY
            ,  LogicalLocation   NVARCHAR(18)
            ,  PALogicalLoc      NVARCHAR(10)
            ,  Facility          NVARCHAR(5)
            ,  PutawayZone       NVARCHAR(10)   
            ,  LocationCategory  NVARCHAR(10)               
            ,  PickZone          NVARCHAR(10)   
     )            
   CREATE INDEX IDX_MZ ON #T_LOC_MZ (Facility, PutawayZone, LocationCategory, PickZone)   

   CREATE TABLE #T_LOC_FS
            (  Loc               NVARCHAR(10)   PRIMARY KEY
            ,  LogicalLocation   NVARCHAR(18)
            ,  PALogicalLoc      NVARCHAR(10)
            ,  Facility          NVARCHAR(5)
            ,  PutawayZone       NVARCHAR(10)   
            ,  LocationCategory  NVARCHAR(10)               
            ,  PickZone          NVARCHAR(10)   
            )            
   CREATE INDEX IDX_FS ON #T_LOC_FS (Facility, PutawayZone, LocationCategory, PickZone)         
   --(Wan02) - END

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''
   SET @c_UserName = SUSER_SNAME()

   IF EXISTS ( SELECT 1
               FROM RECEIPT RH WITH (NOLOCK) 
               JOIN RECEIPTDETAIL RD WITH (NOLOCK) ON RH.Receiptkey = RD.ReceiptKey
               WHERE RH.ReceiptKey = @c_ReceiptKey
               --AND   RD.BeforeReceivedQty > 0
               AND   RD.finalizeflag <> 'Y'
             )
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 63010
      SET @c_ErrMsg = CONVERT(CHAR(5), @n_Err) + ': Not Finalized Receipt Line found' 
                    + '. (ispBatPA02)' 
      GOTO QUIT_SP
   END

   SELECT @c_Facility = RH.Facility
         ,@c_Storerkey = RH.Storerkey --NJOW
         ,@c_Site = RTRIM(RH.UserDefine01)
         ,@c_PADone = RTRIM(RH.UserDefine10)
   FROM RECEIPT RH WITH (NOLOCK) 
   WHERE RH.ReceiptKey = @c_ReceiptKey

   --(Wan01) - START
   --IF @c_PADone <> ''
   --BEGIN
   SET @n_Cnt = 1
   SELECT @n_Cnt = 0
   FROM RECEIPTDETAIL RD WITH (NOLOCK)
   WHERE RD.ReceiptKey = @c_ReceiptKey
   AND   (RD.UserDefine10 = '' OR RD.UserDefine10 IS NULL)

   IF @n_Cnt = 1       
   BEGIN            
      SET @n_Continue = 3
      SET @n_Err = 63020
      SET @c_ErrMsg = CONVERT(CHAR(5), @n_Err) + ': All Receipt Sku had suggested PA before.' 
                     + '. (ispBatPA02)' 
      GOTO QUIT_SP
   END 
   SET @n_Cnt = 0
   --END
   --(Wan01) - END

   BEGIN TRY
      EXEC isp_LostID 1, @c_Storerkey, @c_Facility  --NJOW   
   END TRY
   BEGIN CATCH
      IF @@TRANCOUNT < @n_StartTCnt
      BEGIN
         BEGIN TRAN
      END
   END CATCH

   --(Wan06) - START
   INSERT INTO #t_MSKU
         (  Storerkey
         ,  Sku       
         ,  ItemClass
         ,  MSku  
         )       
   SELECT DISTINCT 
            R.Storerkey
         ,  R.SKU 
         ,  R.ItemClass
         ,  MSKU = MS.SKU 
   FROM ( SELECT RD.Storerkey, RD.Sku, S.ItemClass 
          FROM RECEIPTDETAIL RD (NOLOCK) 
          JOIN SKU S (NOLOCK) ON RD.Storerkey = S.Storerkey 
                              AND RD.Sku = S.Sku 
          WHERE RD.ReceiptKey = @c_ReceiptKey 
          AND   RD.QtyReceived > 0
          AND   RD.FinalizeFlag = 'Y'
          AND  (RD.UserDefine10 = '' OR RD.Userdefine10 IS NULL)            
          )  R
   JOIN SKU MS (NOLOCK) ON  MS.storerkey = @c_Storerkey 
                        AND MS.Itemclass = R.ItemClass
   ORDER BY R.Sku
         ,  R.ItemClass
         ,  MS.Sku 
   --(Wan06) - END

   --(Wan02) - START
   INSERT INTO #T_LOC_HB 
         (  Loc
         ,  LogicalLocation   
         ,  PALogicalLoc       
         ,  Facility
         ,  PutawayZone
         ,  LocationCategory
         ,  PickZone
         )            
   SELECT   DISTINCT 
            L.Loc
         ,  L.LogicalLocation   
         ,  PALogicalLoc = ISNULL(L.PALogicalLoc,'')
         ,  L.Facility
         ,  L.PutawayZone
         ,  L.LocationCategory
         ,  L.PickZone
   FROM CODELKUP CL WITH (NOLOCK) 
   JOIN LOC  L WITH (NOLOCK)  ON  L.PutawayZone = 'HB'
                              AND L.Facility    = @c_Facility
                              AND L.PickZone    = CL.Code2 
   WHERE CL.ListName = 'ALLSORTING'
   AND CL.Code = @c_Site


   INSERT INTO #T_LOC_MZ 
         (  Loc
         ,  LogicalLocation   
         ,  PALogicalLoc   
         ,  Facility
         ,  PutawayZone
         ,  LocationCategory
         ,  PickZone
         )            
   SELECT   DISTINCT 
            L.Loc
         ,  L.LogicalLocation   
         ,  PALogicalLoc = ISNULL(L.PALogicalLoc,'')
         ,  L.Facility
         ,  L.PutawayZone
         ,  L.LocationCategory
         ,  L.PickZone
   FROM (   SELECT DISTINCT RD.ReceiptKey, S.SkuGroup
            FROM RECEIPTDETAIL RD WITH (NOLOCK) 
            JOIN SKU  S WITH (NOLOCK)  ON  RD.Storerkey = S.Storerkey     
                                       AND RD.Sku = S.Sku
            WHERE RD.ReceiptKey =   @c_ReceiptKey
            AND   RD.QtyReceived > 0
            AND   RD.FinalizeFlag = 'Y'
            AND  (RD.UserDefine10 = '' OR RD.Userdefine10 IS NULL)   
            ) PA
   JOIN LOC  L WITH (NOLOCK)  ON  L.PutawayZone = PA.SkuGroup
                              AND L.Facility    = @c_Facility
                              AND L.LocationCategory IN ( 'MEZZANINEB', 'MEZZANINES' )
   WHERE EXISTS (SELECT 1 FROM CODELKUP CL WITH (NOLOCK) WHERE  CL.ListName = 'ALLSORTING'   --(Wan06)
                 AND CL.Code = @c_Site AND CL.Code2 = L.PickZone)                            --(Wan06)

   INSERT INTO #T_LOC_FS
         (  Loc
         ,  LogicalLocation   
         ,  PALogicalLoc   
         ,  Facility
         ,  PutawayZone
         ,  LocationCategory
         ,  PickZone
         )            
   SELECT   DISTINCT 
            L.Loc
         ,  L.LogicalLocation   
         ,  PALogicalLoc = ISNULL(L.PALogicalLoc,'')   
         ,  L.Facility
         ,  L.PutawayZone
         ,  L.LocationCategory
         ,  L.PickZone
   FROM (   SELECT DISTINCT RD.ReceiptKey, S.SkuGroup 
            FROM RECEIPTDETAIL RD WITH (NOLOCK) 
            JOIN SKU  S WITH (NOLOCK)  ON  RD.Storerkey = S.Storerkey     
                                       AND RD.Sku = S.Sku
             WHERE RD.ReceiptKey = @c_ReceiptKey
             AND    RD.QtyReceived > 0
             AND    RD.FinalizeFlag = 'Y'
             AND   (RD.UserDefine10 = '' OR RD.Userdefine10 IS NULL)    
             ) PA
   JOIN LOC  L WITH (NOLOCK)  ON  L.PutawayZone = PA.SkuGroup
                              AND L.Facility    = @c_Facility
                              AND L.LocationCategory IN ( 'FreeSeat' )
   WHERE EXISTS (SELECT 1 FROM CODELKUP CL WITH (NOLOCK) WHERE  CL.ListName = 'ALLSORTING'      --(Wan06)
                 AND CL.Code = @c_Site AND CL.Code2 = L.PickZone)                               --(Wan06)
   --(Wan02) - END

   SET @CUR_RDSKU = CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT RD.Storerkey
         ,RD.Sku
         ,SkuGroup = ISNULL(RTRIM(S.SkuGroup),'')
         ,ItemClass= ISNULL(RTRIM(S.ItemClass),'')
         ,SkuQtyReceived = ISNULL(SUM(RD.QtyReceived),0)
   FROM RECEIPT RH WITH (NOLOCK) 
   JOIN RECEIPTDETAIL RD WITH (NOLOCK) ON RH.Receiptkey = RD.ReceiptKey
   JOIN SKU  S WITH (NOLOCK)  ON  RD.Storerkey = S.Storerkey     
                              AND RD.Sku = S.Sku
   WHERE RH.ReceiptKey = @c_ReceiptKey
   AND    RD.QtyReceived > 0
   AND    RD.FinalizeFlag = 'Y'
   AND    (RD.UserDefine10 = '' OR RD.Userdefine10 IS NULL)    --(Wan01)
   GROUP BY RD.Storerkey
         ,  RD.Sku
         ,  ISNULL(RTRIM(S.SkuGroup),'') 
         ,  ISNULL(RTRIM(S.ItemClass),'')
   ORDER BY RD.Storerkey   
         ,  RD.Sku

   OPEN @CUR_RDSKU
   
   FETCH NEXT FROM @CUR_RDSKU INTO @c_Storerkey
                                 , @c_Sku
                                 , @c_SkuGroup  
                                 , @c_ItemClass 
                                 , @n_SkuQtyReceived  

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @c_Step1  = ''
      SET @c_Step2  = ''
      SET @c_Step3  = ''
      SET @c_Step4  = ''
      SET @c_Step5  = ''    
      SET @c_Step6  = ''
      SET @c_Step7  = ''
      SET @c_Step8  = ''
      SET @c_Step9  = ''
      SET @c_Step10 = ''
      
      SET @d_DateStart = GETDATE()  
      SET @d_SkuDateStart = @d_DateStart   
       
      --(Wan01) - START
      SET @n_PABookingKey = 0
      BEGIN TRAN
      --(Wan01) - END
      SET @c_ReceiptLineNumber = ''
      SET @n_SkuQtyRemaining = @n_SkuQtyReceived
      SET @c_PutawayZone= 'HB'
      SET @c_PickZone   = ''
      SET @c_SuggestLoc = ''
      SET @c_HBLoc      = ''
      SET @n_Strategy   = 0

      SET @n_SkuGrpPKValue = 0
      SELECT @n_SkuGrpPKValue = CASE WHEN  ISNUMERIC(CL.Short) = 1 THEN ISNULL(RTRIM(CL.Short),'') ELSE 0 END
      FROM CODELKUP CL WITH (NOLOCK)
      WHERE CL.ListName = 'NK-PUTAWAY'
      AND   CL.Code2 = @c_Site
      AND   CL.Code = @c_SkuGroup

      SET @n_PKCRWP_MZB= 0 
      SET @n_PKCRW_MZB = 0
      SET @n_PKCRWP_MZS= 0 
      SET @n_PKCRW_MZS = 0
      SET @n_PKCRWP_HB = 0
      SET @n_PKCRW_HB  = 0 

      SELECT @n_PKCRWP_MZB= CASE WHEN ISNUMERIC(SC.UserDefine01) = 1 THEN ISNULL(RTRIM(SC.UserDefine01),'') ELSE 0 END
         ,   @n_PKCRW_MZB = CASE WHEN ISNUMERIC(SC.UserDefine04) = 1 THEN ISNULL(RTRIM(SC.UserDefine04),'') ELSE 0 END
         ,   @n_PKCRWP_MZS= CASE WHEN ISNUMERIC(SC.UserDefine02) = 1 THEN ISNULL(RTRIM(SC.UserDefine02),'') ELSE 0 END
         ,   @n_PKCRW_MZS = CASE WHEN ISNUMERIC(SC.UserDefine05) = 1 THEN ISNULL(RTRIM(SC.UserDefine05),'') ELSE 0 END
         ,   @n_PKCRWP_HB = CASE WHEN ISNUMERIC(SC.UserDefine03) = 1 THEN ISNULL(RTRIM(SC.UserDefine03),'') ELSE 0 END
         ,   @n_PKCRW_HB  = CASE WHEN ISNUMERIC(SC.UserDefine08) = 1 THEN ISNULL(RTRIM(SC.UserDefine08),'') ELSE 0 END
      FROM SKUCONFIG SC WITH (NOLOCK)                        
      WHERE SC.Storerkey = @c_Storerkey                      
      AND   SC.Sku = @c_Sku 
      AND   SC.ConfigType = 'NK-Putaway' 

      IF (@n_PKCRWP_MZB = 0 AND @n_PKCRWP_MZS = 0) OR (@n_PKCRW_MZB = 0 AND @n_PKCRW_MZS = 0) OR (@n_PKCRWP_HB = 0 AND @n_PKCRW_HB = 0)
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 63030
         SET @c_ErrMsg = CONVERT(CHAR(5), @n_Err) + ': Invalid PK Value setup at SkuConfig for sku: ' +RTRIM(@c_Sku)   
                       + '. (ispBatPA02)' 
         GOTO QUIT_SP
      END

      SET @n_SkuPKValueMZB = CASE WHEN @c_Site = 'CRWP' THEN @n_PKCRWP_MZB ELSE @n_PKCRW_MZB END   
      SET @n_SkuPKValueMZS = CASE WHEN @c_Site = 'CRWP' THEN @n_PKCRWP_MZS ELSE @n_PKCRW_MZS END  
      SET @n_SkuPKValueHB  = CASE WHEN @c_Site = 'CRWP' THEN @n_PKCRWP_HB ELSE @n_PKCRW_HB END 
      
      SET @n_QtyConv = 0
      IF @n_SkuPKValueHB > 0 
      BEGIN
         SET @n_QtyConv = FLOOR(@n_SkuQtyRemaining / @n_SkuPKValueHB)
      END

      IF @b_debug = 1
      BEGIN
         SELECT @c_Sku '@c_Sku'
               , @n_SkuQtyRemaining '@n_SkuQtyRemaining' 
               , @n_QtyConv '@n_QtyConv'
               , @n_SkuGrpPKValue '@n_SkuGrpPKValue'
               , @n_SkuPKValueHB '@n_SkuPKValueHB'
               , @n_SkuPKValueMZB '@n_SkuPKValueMZB'
               , @n_SkuPKValueMZS '@n_SkuPKValueMZS'
               , @n_SkuQtyRemaining - (@n_SkuPKValueHB * @n_QtyConv) 'Check Remaining Qty'
      END        
      
      SET @d_DateEnd = GETDATE()   
      
      SET @c_Step1 = CONVERT(NVARCHAR(10),DATEDIFF(ms, @d_DateStart, @d_DateEnd))  

      IF @n_SkuQtyRemaining - (@n_SkuPKValueHB * @n_QtyConv) < @n_SkuGrpPKValue  
      BEGIN
         TRUNCATE TABLE #t_PickZone
         TRUNCATE TABLE #T_Zone                                                        --(Wan06)
         TRUNCATE TABLE #t_PICKZONESUMM

         SET @n_QtyRemaining2MZ = @n_SkuQtyRemaining - (@n_SkuPKValueHB * @n_QtyConv)  --(Wan06)
         SET @d_DateStart = GETDATE()  

         --(Wan08) - START
         --IF EXISTS( 
         --            SELECT 1
         --            FROM LOC L WITH (NOLOCK) 
         --            JOIN CODELKUP CL WITH (NOLOCK) ON  CL.ListName = 'ALLSORTING'      
         --                                           AND CL.Code  = @c_Site 
         --                                           AND CL.Code2 = L.PickZone
         --            JOIN LOTxLOCxID LLI WITH (NOLOCK) ON L.Loc = LLI.Loc 
         --            WHERE L.PutawayZone = @c_PutawayZone                                         
         --            AND   L.Facility = @c_Facility
         --            AND   L.LocationCategory IN ( 'MEZZANINEB', 'MEZZANINES' )
         --            AND   LLI.Storerkey = @c_Storerkey
         --            AND   LLI.Sku = @c_Sku
         --            GROUP BY L.PutawayZone, L.Facility, LLI.Storerkey, LLI.Sku
         --            HAVING SUM((LLI.Qty - LLI.QtyPicked) + LLI.PendingMoveIN) = 0
         --         )
         --BEGIN
         --   GOTO EMPTY_LOC_PZ
         --END
         --(Wan08) - END

         SET @c_PutawayZone= @c_SkuGroup                                   
         SET @c_StrategyType = 'SKU'                                       --(Wan02)
         -- Find Best Fit PickZone 
         INSERT INTO #t_PickZone (Sku, StrategyType, PickZone, Loc, MZBAvailQTY, MZSAvailQTY)  
         SELECT  Sku = @c_Sku
               , StrategyType = 'SKU' 
               , L.PickZone
               , L.Loc
               , MZBAvailQTY = CASE WHEN L.LocationCategory = 'MEZZANINEB' AND @n_SkuPKValueMZB > SUM(LLI.Qty - LLI.QtyPicked + LLI.PendingMoveIN) --(Wan07)
                                    THEN @n_SkuPKValueMZB - SUM(LLI.Qty - LLI.QtyPicked + LLI.PendingMoveIN) ELSE 0 END                            --(Wan07)
               , MZSAvailQTY = CASE WHEN L.LocationCategory = 'MEZZANINES' AND @n_SkuPKValueMZS > SUM(LLI.Qty - LLI.QtyPicked + LLI.PendingMoveIN) --(Wan07)   
                                    THEN @n_SkuPKValueMZS - SUM(LLI.Qty - LLI.QtyPicked + LLI.PendingMoveIN) ELSE 0 END                            --(Wan07)
         FROM #T_LOC_MZ L                                                  
         JOIN LOTxLOCxID LLI WITH (NOLOCK) ON L.Loc = LLI.Loc 
         WHERE L.PutawayZone = @c_PutawayZone                                         
         AND   L.Facility = @c_Facility
         AND   L.LocationCategory IN ( 'MEZZANINEB', 'MEZZANINES' )
         AND   LLI.Storerkey = @c_Storerkey
         AND   LLI.Sku = @c_Sku
         AND   (LLI.Qty - LLI.QtyPicked) + LLI.PendingMoveIN > 0                                                                       --(Wan07)
         AND   1 = (SELECT COUNT(DISTINCT LLI1.Sku) FROM LOTxLOCxID LLI1 WITH (NOLOCK)                               --(Wan06)  
                    WHERE L.Loc = LLI1.Loc AND (LLI1.Qty - LLI1.QtyPicked) + LLI1.PendingMoveIN > 0 AND LLI1.Storerkey = @c_Storerkey)  --(Wan07) 
         GROUP BY L.PickZone
               ,  L.Loc
               ,  L.LocationCategory
                                       
         SET @d_DateEnd = GETDATE()                       
                                                          
         SET @c_Step2 = CONVERT(NVARCHAR(10),DATEDIFF(ms, @d_DateStart, @d_DateEnd))    

         --(Wan06) - START
         INSERT INTO #T_Zone (PickZone)
         SELECT DISTINCT
               PickZone
         FROM #t_PickZone T --WHERE T.MZBAvailQTY + T.MZSAvailQTY > 0
         GROUP BY T.PickZone
                                       
         IF NOT EXISTS (SELECT 1 FROM #T_Zone T) 
         BEGIN
            SET @d_DateStart = GETDATE()  
                     
            SET @c_StrategyType = 'MATERIAL'                                   
            
            INSERT INTO #T_Zone (PickZone)
            SELECT  DISTINCT 
                    L.PickZone
            FROM #T_LOC_MZ L                                                                                                  
            JOIN LOTxLOCxID LLI WITH (NOLOCK) ON L.Loc = LLI.Loc 
            JOIN #t_MSKU    S   ON   S.Storerkey = LLI.Storerkey  AND S.MSKU = LLI.SKU 
            WHERE L.PutawayZone = @c_PutawayZone                
            AND   L.Facility    = @c_Facility
            AND   LLI.Storerkey = @c_Storerkey 
            AND   S.Storerkey   = @c_Storerkey                                                                                 
            AND   S.Sku = @c_Sku                                                                                               
            AND   S.ItemClass = @c_ItemClass                                                                                        
            AND   (LLI.Qty - LLI.QtyPicked) + LLI.PendingMoveIN > 0                             --(wan07)
            GROUP BY L.PickZone
                  
            SET @d_DateEnd = GETDATE()                       
                                                             
            SET @c_Step3 = CONVERT(NVARCHAR(10),DATEDIFF(ms, @d_DateStart, @d_DateEnd))                      
         END

         EMPTY_LOC_PZ:
         IF NOT EXISTS (SELECT 1 FROM #T_Zone T )
         BEGIN
            SET @c_StrategyType = 'EMPTYLOC' 
            SET @d_DateStart = GETDATE()  

            --(Wan07) - START
           -- INSERT INTO #T_Zone (PickZone)
           -- SELECT  DISTINCT 
           --         L.PickZone
           -- FROM #T_LOC_MZ L
           -- GROUP BY L.PickZone  
            INSERT INTO #T_Zone (PickZone)
            SELECT TOP 1 T.PickZone
            FROM (
                  SELECT L.PickZone
                           , LocAvailQty = ISNULL(SUM(CASE WHEN L.LocationCategory = 'MEZZANINEB' THEN @n_SkuPKValueMZB 
                                                           WHEN L.LocationCategory = 'MEZZANINES' THEN @n_SkuPKValueMZS
                                                           ELSE 0 END
                                                      ),0)
                           , LocCnt = COUNT(L.Loc)
                  FROM #T_LOC_MZ L 
                  WHERE L.PutawayZone = @c_PutawayZone                
                  AND   L.Facility    = @c_Facility
                  AND   0 = (SELECT ISNULL(SUM(LLI.Qty - LLI.QtyPicked + LLI.PendingMoveIN),0) FROM LOTxLOCxID LLI WITH (NOLOCK) --(Wan07) 
                             WHERE L.Loc = LLI.Loc AND LLI.Storerkey = @c_Storerkey)
                  GROUP BY L.PickZone
                ) T
            ORDER BY CASE WHEN T.LocAvailQty >= @n_QtyRemaining2MZ THEN 0 ELSE 9 END  
                   , T.LocCnt DESC
            --(Wan07) - END

            SET @d_DateEnd = GETDATE()                       
            SET @c_Step4 = CONVERT(NVARCHAR(10),DATEDIFF(ms, @d_DateStart, @d_DateEnd))  
         END

         IF @b_debug = 2
         BEGIN     
            SELECT @c_StrategyType,*
            FROM #T_Zone T
            ORDER BY T.PickZone
         END

         SET @d_DateStart = GETDATE()   
         SET @c_PickZone = ''
         WHILE 1=1 
         BEGIN
            SELECT TOP 1 @c_PickZone = T.PickZone
            FROM #T_Zone T
            WHERE T.PickZone > @c_PickZone
            ORDER BY T.PickZone

            IF @@ROWCOUNT = 0
            BEGIN 
               BREAK
            END
 
            SET @n_QtyMZ2Process = @n_QtyRemaining2MZ
            
            IF @c_StrategyType = 'SKU'
            BEGIN
               SELECT @n_QtyMZ2Process = @n_QtyRemaining2MZ - ISNULL(SUM(T.MZBAvailQTY + T.MZSAvailQTY),0)
               FROM #t_PickZone T
               WHERE T.PickZone = @c_PickZone
            END

            IF @n_QtyMZ2Process > 0 
            BEGIN
               SET @c_LocationCategory = 'MEZZANINES'
               IF @n_SkuPKValueMZS > @n_SkuPKValueMZB
               BEGIN
                  SET @c_LocationCategory = 'MEZZANINEB'
               END 

               SET @n_Strategy = 0
               WHILE @n_Strategy < 2
               BEGIN
                  IF  @c_LocationCategory = 'MEZZANINEB' 
                  BEGIN
                     SET @c_LocationCategory = 'MEZZANINES' 
                     SET @n_SkuPKValue = @n_SkuPKValueMZS
                  END
                  ELSE 
                  BEGIN
                     SET @c_LocationCategory = 'MEZZANINEB' 
                     SET @n_SkuPKValue = @n_SkuPKValueMZB
                  END 

                  SET @n_NoOfMZ = 0

                  IF @n_SkuPKValue > 0 
                  BEGIN
                     SET @n_NoOfMZ = ISNULL(CEILING(@n_QtyMZ2Process / (@n_SkuPKValue * 1.00)),0)
                  END

                  IF @b_debug IN ( 1,2)
                  BEGIN     
                     select @n_NoOfMZ '@n_NoOfMZ', @n_QtyMZ2Process '@n_QtyMZ2Process',@n_SkuPKValue '@n_SkuPKValue'
                           ,@c_PickZone '@c_PickZone', @c_LocationCategory '@c_LocationCategory', @c_PutawayZone '@c_PutawayZone'
                  END

                  IF @n_NoOfMZ > 0
                  BEGIN
                     INSERT INTO #t_PickZone (Sku, StrategyType, PickZone, Loc, MZBAvailQTY, MZSAvailQTY)
                     SELECT TOP (@n_NoOfMZ)  
                          Sku = @c_Sku
                        , StrategyType = @c_StrategyType                                                                               
                        , L.PickZone
                        , L.Loc
                        , MZBAvailQTY = CASE WHEN @c_LocationCategory = 'MEZZANINEB' THEN @n_SkuPKValueMZB ELSE 0 END
                        , MZSAvailQTY = CASE WHEN @c_LocationCategory = 'MEZZANINES' THEN @n_SkuPKValueMZS ELSE 0 END
                     FROM #T_LOC_MZ L 
                     LEFT JOIN LOTxLOCxID LLI WITH (NOLOCK) ON L.Loc = LLI.Loc AND LLI.Storerkey = @c_Storerkey
                     WHERE L.PutawayZone = @c_PutawayZone                
                     AND   L.Facility    = @c_Facility
                     AND   L.LocationCategory = @c_LocationCategory                                                      
                     AND   L.PickZone = @c_PickZone
                     GROUP BY L.PickZone
                        ,  L.Loc
                        ,  L.LocationCategory
                     HAVING  SUM( ISNULL(LLI.Qty,0) - ISNULL(LLI.QtyPicked,0) + ISNULL(LLI.PendingMoveIN,0)) = 0  -- (Wan07)
                     ORDER BY L.PickZone
                  END
                  SET @n_Strategy = @n_Strategy + 1
               END
            END
         END
                                 
         SET @d_DateEnd = GETDATE()                       
                                                             
         SET @c_Step5 = CONVERT(NVARCHAR(10),DATEDIFF(ms, @d_DateStart, @d_DateEnd))  
           
         IF @b_debug = 2
         BEGIN    
            SELECT DISTINCT MZ.PickZOne, MZ.LocationCategory
            FROM #T_LOC_MZ MZ
            WHERE EXISTS (SELECT 1 FROM #T_Zone T WHERE T.Pickzone = MZ.Pickzone)
            ORDER BY MZ.PickZOne,  MZ.LocationCategory

            SELECT DISTINCT MZ.PickZOne, MZ.LocationCategory
            FROM #T_LOC_MZ MZ
            WHERE MZ.LocationCategory = 'MEZZANINEB'
            ORDER BY MZ.PickZOne,  MZ.LocationCategory
                
            SELECT *
            FROM  #t_PickZone T
            ORDER BY T.PickZone
         END
                             
         SET @n_Strategy = 0                  
         SET @c_PickZone = ''  

         SET @d_DateStart = GETDATE()     
         INSERT INTO #t_PICKZONESUMM (Sku, StrategyType, PickZone, MZBAvailQTY, MZSAvailQTY, LocAvailQTY, PZPriority)
         SELECT   T.Sku
               ,  T.StrategyType
               ,  T.PickZone
               ,  MZBAvailQTY= SUM(T.MZBAvailQTY)
               ,  MZSAvailQTY= SUM(T.MZSAvailQTY)
               ,  LocAvailQTY= SUM(T.MZBAvailQTY + T.MZSAvailQTY)
               --(Wan06) - START
               ,  PZPriority = CASE WHEN SUM(T.MZBAvailQTY + T.MZSAvailQTY)  = @n_QtyRemaining2MZ
                                    THEN 10
                                    WHEN SUM(T.MZBAvailQTY) = @n_QtyRemaining2MZ AND @n_SkuPKValueMZB > @n_SkuPKValueMZS
                                    THEN 20
                                    WHEN SUM(T.MZSAvailQTY) = @n_QtyRemaining2MZ AND @n_SkuPKValueMZB < @n_SkuPKValueMZS
                                    THEN 30
                                    WHEN SUM(T.MZBAvailQTY) = @n_QtyRemaining2MZ AND @n_SkuPKValueMZB < @n_SkuPKValueMZS
                                    THEN 40
                                    WHEN SUM(T.MZSAvailQTY) = @n_QtyRemaining2MZ AND @n_SkuPKValueMZB > @n_SkuPKValueMZS
                                    THEN 50
                                    WHEN SUM(T.MZBAvailQTY + T.MZSAvailQTY)  > @n_QtyRemaining2MZ 
                                    THEN 60
                                    ELSE 90
                                    END
               --(Wan06) - END
         FROM #t_PickZone T 
         GROUP BY T.Sku
               ,  T.StrategyType
               ,  T.PickZone
         ORDER BY PZPriority
               ,  LocAvailQTY
               ,  T.PickZone

         SET @d_DateEnd = GETDATE()                       
                                                          
         SET @c_Step6 = CONVERT(NVARCHAR(10),DATEDIFF(ms, @d_DateStart, @d_DateEnd))  
         
         IF @b_debug = 2
         BEGIN     
            SELECT *
            FROM #t_PICKZONESUMM T
            ORDER BY RowID
         END

         IF @c_PickZone = ''
         BEGIN
            SELECT TOP 1 
                   @c_PickZone = T.PickZone
                ,  @n_LocAvailQTY = T.LocAvailQTY
            FROM #t_PICKZONESUMM T
            ORDER BY RowID
         END

         IF @c_PickZone = '' OR @n_LocAvailQTY < @n_QtyRemaining2MZ
         BEGIN
            --(Wan06) - START
            SET @n_Cnt = 0
  
            IF @c_PickZone = ''
            BEGIN
            --WL01 Start
               IF EXISTS (SELECT 1 FROM #T_Zone T )
               BEGIN
                  SELECT TOP 1 
                           @c_PickZone = L.PickZone
                        ,  @n_Cnt = 1
                  FROM #T_LOC_FS L                                               --(Wan02)
                  WHERE L.PutawayZone = @c_PutawayZone           
                  AND   L.Facility = @c_Facility
                  AND   L.LocationCategory = 'FreeSeat'
                  AND   0 = (SELECT ISNULL(SUM(LLI.Qty - LLI.QtyPicked + LLI.PendingMoveIN),0) FROM LOTxLOCxID LLI WITH (NOLOCK) --(Wan07) 
                             WHERE L.Loc = LLI.Loc AND LLI.Storerkey = @c_Storerkey)
                  AND   L.PickZone > @c_PickZone
                  AND   EXISTS (SELECT 1 FROM #T_Zone T WHERE T.PickZone = L.PickZone) --(Wan06) -3
                  ORDER BY L.PickZone
               END
               ELSE
               BEGIN
                  SELECT TOP 1 
                           @c_PickZone = L.PickZone
                        ,  @n_Cnt = 1
                  FROM #T_LOC_FS L                                               --(Wan02)
                  WHERE L.PutawayZone = @c_PutawayZone           
                  AND   L.Facility = @c_Facility
                  AND   L.LocationCategory = 'FreeSeat'
                  AND   0 = (SELECT ISNULL(SUM(LLI.Qty - LLI.QtyPicked + LLI.PendingMoveIN),0) FROM LOTxLOCxID LLI WITH (NOLOCK) --(Wan07) 
                             WHERE L.Loc = LLI.Loc AND LLI.Storerkey = @c_Storerkey)
                  AND   L.PickZone > @c_PickZone
                  ORDER BY L.PickZone
               END
       --WL01 END
               SET @n_Strategy = 4        -- DIRECT FIND FreeSeat as No MZ PickZOne
            END
            ELSE
            BEGIN
               SELECT TOP 1 
                        @n_Cnt = 1
               FROM #T_LOC_FS L                                               
               WHERE L.PutawayZone = @c_PutawayZone           
               AND   L.Facility = @c_Facility
               AND   L.LocationCategory = 'FreeSeat'
               AND   0 = (SELECT ISNULL(SUM(LLI.Qty - LLI.QtyPicked + LLI.PendingMoveIN),0) FROM LOTxLOCxID LLI WITH (NOLOCK) --(Wan07)
                          WHERE L.Loc = LLI.Loc AND LLI.Storerkey = @c_Storerkey)
               AND   L.PickZone = @c_PickZone
               ORDER BY L.PickZone
            END

            IF @n_Cnt = 0 
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 63040
               SET @c_ErrMsg = CONVERT(CHAR(5), @n_Err) + ': No Available Free Seat to PA ' + @c_PutawayZone + ' ' + @c_PickZone + ' ' + @c_Sku + ' ' + cast(@n_Strategy as nvarchar(10))
                             + '. (ispBatPA02)' 
               GOTO QUIT_SP
            END
            SET @n_Cnt = 0
            --(Wan06) - END
         END
      END
      

      SET @n_LinePAQty = 0
      SET @c_ReceiptLineNumber = ''
      WHILE @n_SkuQtyRemaining > 0 
      BEGIN 
         IF @b_debug = 1
         BEGIN
            SELECT @n_SkuQtyRemaining '@n_SkuQtyRemaining'
            , @n_SkuGrpPKValue '@n_SkuGrpPKValue'
            , @n_PKCRWP_HB '@n_PKCRWP_HB'
            , @n_PKCRW_HB '@n_PKCRW_HB'
         END

         SET @c_SuggestLoc = ''   
         IF @n_SkuQtyRemaining >= @n_SkuGrpPKValue  
         BEGIN
            --Find HB PickZone
            SET @c_PutawayZone= 'HB'
            SET @n_SkuPKValue = CASE WHEN @c_Site = 'CRWP' THEN @n_PKCRWP_HB ELSE @n_PKCRW_HB END 
               
            IF @c_HBLoc = ''
            BEGIN 
               --(Wan02) - START        
               --SELECT TOP 1 @c_HBLoc = L.Loc
               --FROM CODELKUP CL WITH (NOLOCK) 
               --JOIN LOC L WITH (NOLOCK) ON CL.Code2 = L.PickZone 
               --WHERE CL.ListName = 'ALLSORTING'
               --AND   CL.Code = @c_Site
               --AND   L.PutawayZone = @c_PutawayZone
               --AND   L.Facility = @c_Facility
               --AND   0 = (SELECT ISNULL(SUM(LLI.Qty + LLI.PendingMoveIN * 1.00),0) FROM LOTxLOCxID LLI WITH (NOLOCK) -- v1.7
               --           WHERE L.Loc = LLI.Loc)                                                                     -- v1.7

               SELECT TOP 1 @c_HBLoc = L.Loc
               FROM  #T_LOC_HB L WITH (NOLOCK)  
               WHERE L.PutawayZone = @c_PutawayZone
               AND   L.Facility = @c_Facility
               AND   0 = (SELECT ISNULL(SUM(LLI.Qty - LLI.QtyPicked + LLI.PendingMoveIN),0) FROM LOTxLOCxID LLI WITH (NOLOCK)  -- v1.7 --(Wan07)
                          WHERE L.Loc = LLI.Loc AND LLI.Storerkey = @c_Storerkey)                              -- v1.7   --(Wan06)
               --(Wan02) - END             
            END
            SET @c_SuggestLoc = @c_HBLoc

            -- v1.7 - START
            IF @c_SuggestLoc = ''
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 63050
               SET @c_ErrMsg = CONVERT(CHAR(5), @n_Err) + ': HB loc not found.'
                              + '. (ispBatPA02)' 
               GOTO QUIT_SP 
            END
            SET @c_HBLoc = ''                                                                                           --(Wan06) - 2
            -- v1.7 - END
         END
         ELSE
         BEGIN
            IF @n_Strategy > 0
            BEGIN
               SET @n_Strategy = @n_Strategy - 1  -- To repeat the same strategy FOR MZ
            END

            SET @c_PutawayZone= @c_SkuGroup

            IF @b_debug = 1
            BEGIN
               SELECT @c_PickZone '@c_PickZone'
               , @n_SkuPKValueMZB '@n_SkuPKValueMZB'
               , @n_SkuPKValueMZS '@n_SkuPKValueMZS'
               , @n_Strategy '@n_Strategy'
            END

            --Find Loc
            IF @c_SuggestLoc = '' AND @n_Strategy < 1
            BEGIN
               SET @c_LocationCategory = 'MEZZANINEB' 
               SET @n_SkuPKValue = @n_SkuPKValueMZB

               SELECT TOP 1 @c_SuggestLoc = L.Loc
                        ,   @n_SkuPKValue = @n_SkuPKValue - SUM(LLI.Qty - LLI.QtyPicked + LLI.PendingMoveIN)                              --(Wan07)
               --FROM LOC L WITH (NOLOCK)                         --(Wan02)
               FROM #T_LOC_MZ L                                   --(Wan02)
               JOIN LOTxLOCxID LLI (NOLOCK) ON L.Loc = LLI.Loc 
               WHERE L.PutawayZone = @c_PutawayZone
               AND L.PickZone = @c_PickZone
               AND L.Facility = @c_Facility
               AND L.LocationCategory = @c_LocationCategory
               AND LLI.Storerkey = @c_Storerkey
               AND LLI.Sku = @c_Sku
               AND LLI.Qty - LLI.QtyPicked + LLI.PendingMoveIN > 0                                                                        --(Wan07)
               AND   1 = (SELECT COUNT(DISTINCT LLI1.Sku) FROM LOTxLOCxID LLI1 WITH (NOLOCK) 
                          WHERE L.Loc = LLI1.Loc AND LLI1.Qty - LLI1.QtyPicked + LLI1.PendingMoveIN > 0 AND LLI1.Storerkey = @c_Storerkey)--(Wan07) 
               GROUP BY L.Loc 
               HAVING SUM(LLI.Qty - LLI.QtyPicked + LLI.PendingMoveIN) < @n_SkuPKValue                                                    --(Wan07) 
               ORDER BY MIN(L.LogicalLocation)

               IF @c_SuggestLoc = ''
               BEGIN
                  SET @n_Strategy =  1
               END
            END

            IF @c_SuggestLoc = '' AND @n_Strategy < 2
            BEGIN
               SET @c_LocationCategory = 'MEZZANINES' 
               SET @n_SkuPKValue = @n_SkuPKValueMZS

               SELECT TOP 1 @c_SuggestLoc = L.Loc
                        ,   @n_SkuPKValue = @n_SkuPKValue - SUM(LLI.Qty - LLI.QtyPicked + LLI.PendingMoveIN)                              --(Wan07)
               --FROM LOC L WITH (NOLOCK)                         --(Wan02)
               FROM #T_LOC_MZ L                                   --(Wan02)
               JOIN LOTxLOCxID LLI (NOLOCK) ON L.Loc = LLI.Loc
               WHERE L.PutawayZone = @c_PutawayZone
               AND L.PickZone = @c_PickZone
               AND L.Facility = @c_Facility
               AND L.LocationCategory = @c_LocationCategory
               AND LLI.Storerkey = @c_Storerkey
               AND LLI.Sku = @c_Sku
               AND LLI.Qty - LLI.QtyPicked + LLI.PendingMoveIN > 0                                                                        --(Wan07) 
               AND   1 = (SELECT COUNT(DISTINCT LLI1.Sku) FROM LOTxLOCxID LLI1 WITH (NOLOCK) 
                          WHERE L.Loc = LLI1.Loc AND LLI1.Qty - LLI1.QtyPicked + LLI1.PendingMoveIN > 0 AND LLI1.Storerkey = @c_Storerkey)--(Wan07) 
               GROUP BY L.Loc 
               HAVING SUM(LLI.Qty - LLI.QtyPicked + LLI.PendingMoveIN) < @n_SkuPKValue                                                    --(Wan07)
               ORDER BY MIN(L.LogicalLocation)                                                                                            --(Wan07)

               IF @c_SuggestLoc = ''
               BEGIN
                  SET @n_Strategy =  2
               END
            END

            IF @c_SuggestLoc = '' AND @n_Strategy < 3
            BEGIN
               SET @c_LocationCategory = 'MEZZANINES'
    
               IF @n_SkuPKValueMZB >= @n_SkuPKValueMZS
               BEGIN
                  SET @c_LocationCategory = 'MEZZANINEB'
               END

               -- Get from smaller loc if sku remaining qty Both SKU PK Value  (best fit) 
               IF @n_SkuQtyRemaining < @n_SkuPKValueMZS AND @n_SkuPKValueMZS < @n_SkuPKValueMZB
               BEGIN
                  SET @c_LocationCategory = 'MEZZANINES'
               END

               IF @n_SkuQtyRemaining < @n_SkuPKValueMZB AND @n_SkuPKValueMZB < @n_SkuPKValueMZS
               BEGIN
                  SET @c_LocationCategory = 'MEZZANINEB'
               END

               -- Get from loc if sku remaining qty > one of SKU PK Value (best fit)
               IF @n_SkuQtyRemaining < @n_SkuPKValueMZS AND @n_SkuPKValueMZB < @n_SkuQtyRemaining 
               BEGIN
                  SET @c_LocationCategory = 'MEZZANINES'
               END

               IF @n_SkuQtyRemaining < @n_SkuPKValueMZB AND @n_SkuPKValueMZS < @n_SkuQtyRemaining  
               BEGIN
                  SET @c_LocationCategory = 'MEZZANINEB'
               END

               -- Get from loc if sku remaining qty can be fully fit into a empty loc
               IF @n_SkuPKValueMZB > 0 AND @n_SkuQtyRemaining % @n_SkuPKValueMZB = 0
               BEGIN
                  SET @c_LocationCategory = 'MEZZANINEB'
               END

               IF @n_SkuPKValueMZS > 0 AND @n_SkuQtyRemaining % @n_SkuPKValueMZS = 0
               BEGIN
                  SET @c_LocationCategory = 'MEZZANINES'
               END
               
               SET @n_Cnt = 1
               WHILE @c_SuggestLoc = '' AND @n_Cnt <= 2
               BEGIN
                  IF @b_debug = 1
                  BEGIN
                     SELECT @c_LocationCategory '@c_LocationCategory'
                     , @c_PickZone '@c_PickZone'
                     , @n_Strategy '@n_Strategy'
                     , @n_SkuPKValueMZB '@n_SkuPKValueMZB'
                     , @n_SkuPKValueMZS '@n_SkuPKValueMZS'
                  END

                  --(Wan06-2) - START
                  IF @c_LocationCategory = 'MEZZANINEB'
                  BEGIN
                     SET @n_SkuPKValue = @n_SkuPKValueMZB
                  END
                  ELSE
                  BEGIN
                     SET @n_SkuPKValue = @n_SkuPKValueMZS
                  END

                  IF @n_SkuPKValue > 0 
                  BEGIN
                  --(Wan06-2) - END
                     SELECT TOP 1 @c_SuggestLoc = L.Loc
                     --FROM LOC L WITH (NOLOCK)                         --(Wan02)
                     FROM #T_LOC_MZ L                                   --(Wan02)
                     WHERE L.PutawayZone = @c_PutawayZone
                     AND L.PickZone = @c_PickZone
                     AND L.Facility = @c_Facility
                     AND L.LocationCategory = @c_LocationCategory
                     AND   0 = (SELECT ISNULL(SUM(LLI.Qty - LLI.QtyPicked + LLI.PendingMoveIN),0) FROM LOTxLOCxID LLI WITH (NOLOCK) --(Wan07) 
                                WHERE L.Loc = LLI.Loc AND LLI.Storerkey = @c_Storerkey)      --(Wan06) 
                     ORDER BY L.LogicalLocation
                  END--(Wan06-2)

                  IF @c_SuggestLoc = ''
                  BEGIN
                     SET @n_Strategy = 3
                     IF @n_Cnt = 1
                     BEGIN
                        IF @c_LocationCategory = 'MEZZANINEB'
                        BEGIN
                           SET @c_LocationCategory = 'MEZZANINES' 
                        END
                        ELSE
                        BEGIN
                           SET @c_LocationCategory = 'MEZZANINEB' 
                        END
                     END
                     SET @n_Cnt = @n_Cnt + 1
                  END
               END
            END 

            IF @c_SuggestLoc = '' AND @n_Strategy < 4 -- Free Seat
            BEGIN
               SET @c_LocationCategory = 'FreeSeat'
               SELECT TOP 1 @c_SuggestLoc = L.Loc
               --FROM LOC L WITH (NOLOCK)                         --(Wan02)
               FROM #T_LOC_FS L                                   --(Wan02)
               WHERE L.PutawayZone = @c_PutawayZone
               AND L.PickZone = @c_PickZone
               AND L.Facility = @c_Facility
               AND L.LocationCategory = @c_LocationCategory
               AND   0 = (SELECT ISNULL(SUM(LLI.Qty + LLI.QtyPicked + LLI.PendingMoveIN),0) FROM LOTxLOCxID LLI WITH (NOLOCK)-- (Wan07)
                          WHERE L.Loc = LLI.Loc AND LLI.Storerkey = @c_Storerkey)         --(Wan06) 
               ORDER BY L.LogicalLocation

               SET @n_SkuPKValue = @n_SkuQtyRemaining
            END
         END

         IF @c_SuggestLoc = ''
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 63060
            SET @c_ErrMsg = CONVERT(CHAR(5), @n_Err) + ': No Suggest PA Loc Found' 
                          + '. (ispBatPA02)' 
            GOTO QUIT_SP
         END

         IF @b_debug = 1
         BEGIN
            SELECT @c_LocationCategory '@c_LocationCategory'
            , @c_PickZone '@c_PickZone'
            , @n_Strategy '@n_Strategy'
            , @n_SkuPKValueMZB '@n_SkuPKValueMZB'
            , @n_SkuPKValueMZS '@n_SkuPKValueMZS'
            , @n_SkuPKValue '@n_SkuPKValue'
            , @n_SkuQtyRemaining '@n_SkuQtyRemaining'
            , @c_Sku '@c_Sku'
            , @c_SuggestLoc '@c_SuggestLoc'
         END


         IF @n_SkuQtyRemaining < @n_SkuPKValue 
         BEGIN
            SET @n_PAToLocQty = @n_SkuQtyRemaining
         END
         ELSE
         BEGIN
            SET @n_PAToLocQty = @n_SkuPKValue
         END

         SET @n_SkuQtyRemaining = @n_SkuQtyRemaining - @n_PAToLocQty

         WHILE @n_PAToLocQty > 0
         BEGIN
            SELECT TOP 1 
                     @c_ReceiptLineNumber = RD.ReceiptLineNumber
                  ,  @c_FromLoc     = RD.ToLoc
                  ,  @c_FromID      = CASE WHEN LOC.LoseId = '1' THEN '' ELSE RD.ToID END  --NJOW      
                  ,  @n_QtyReceived = RD.QtyReceived - @n_LinePAQty
                  ,  @c_lottable01 = RD.Lottable01                         --(Wan04)
                  ,  @c_lottable02 = RD.Lottable02                         --(Wan04)
                  ,  @c_lottable03 = RD.Lottable03                         --(Wan04)
                  ,  @d_lottable04 = RD.Lottable04                         --(Wan04)
                  ,  @d_lottable05 = RD.Lottable05                         --(Wan04)
                  ,  @c_lottable06 = RD.Lottable06                         --(Wan04)
                  ,  @c_lottable07 = RD.Lottable07                         --(Wan04)
                  ,  @c_lottable08 = RD.Lottable08                         --(Wan04)
                  ,  @c_lottable09 = RD.Lottable09                         --(Wan04)
                  ,  @c_lottable10 = RD.Lottable10                         --(Wan04)
                  ,  @c_lottable11 = RD.Lottable11                         --(Wan04)
                  ,  @c_lottable12 = RD.Lottable12                         --(Wan04)
                  ,  @d_lottable13 = RD.Lottable13                         --(Wan04)
                  ,  @d_lottable14 = RD.Lottable14                         --(Wan04)
                  ,  @d_lottable15 = RD.Lottable15                         --(Wan04)
            FROM RECEIPTDETAIL RD (NOLOCK)
            JOIN LOC (NOLOCK) ON RD.ToLoc = LOC.Loc  --NJOW
            WHERE RD.ReceiptKey = @c_ReceiptKey
            AND   RD.Storerkey = @c_Storerkey
            AND   RD.Sku = @c_Sku
            AND   RD.QtyReceived > 0
            AND   RD.FinalizeFlag = 'Y'
            AND   RD.ReceiptLineNumber > @c_ReceiptLineNumber
            ORDER BY RD.ReceiptLineNumber                                  --(Wan03)

            IF @@ROWCOUNT = 0
            BEGIN
               BREAK
            END

            SET @c_SourceKey = @c_ReceiptKey + @c_ReceiptLineNumber
            SET @c_ReceiptLineUpdate = @c_ReceiptLineNumber                --(Wan01)  

            --Get Lot
            --SET @c_Fromlot = ''                                            --(Wan04)
            --SELECT @c_Fromlot = ITRN.Lot
            --FROM ITRN WITH (NOLOCK)
            --WHERE ITRN.TranType = 'DP'
            --AND ITRN.SourceKey = @c_SourceKey
            --AND ITRN.SourceType IN ('ntrReceiptDetailAdd', 'ntrReceiptDetailUpdate')

            --(Wan04) - START
            SET @c_Fromlot = '' 
            SET @b_Success = 1                                           
            EXECUTE nsp_lotlookup                              
                    @c_Storerkey  = @c_Storerkey               
                  , @c_sku        = @c_sku                     
                  , @c_lottable01 = @c_Lottable01              
                  , @c_lottable02 = @c_Lottable02              
                  , @c_lottable03 = @c_Lottable03              
                  , @c_lottable04 = @d_Lottable04              
                  , @c_lottable05 = @d_Lottable05              
                  , @c_lottable06 = @c_Lottable06              
                  , @c_lottable07 = @c_Lottable07              
                  , @c_lottable08 = @c_Lottable08              
                  , @c_lottable09 = @c_Lottable09              
                  , @c_lottable10 = @c_Lottable10              
                  , @c_lottable11 = @c_Lottable11              
                  , @c_lottable12 = @c_Lottable12              
                  , @c_lottable13 = @d_Lottable13              
                  , @c_lottable14 = @d_Lottable14              
                  , @c_lottable15 = @d_Lottable15              
                  , @c_Lot        = @c_FromLot  OUTPUT         
                  , @b_Success    = @b_Success  OUTPUT         
                  , @n_err        = @n_err      OUTPUT         
                  , @c_ErrMsg     = @c_ErrMsg   OUTPUT         

            IF @b_Success <> 1
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 63062
               SET @c_ErrMsg = CONVERT(CHAR(5), @n_Err) + ': Error Executing nsp_lotlookup. ' 
               GOTO QUIT_SP
            END

            IF @c_Fromlot = '' 
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 63065
               SET @c_ErrMsg = CONVERT(CHAR(5), @n_Err) + ': Lot Not found for Receipt Line #: ' + RTRIM(@c_ReceiptLineNumber)
               GOTO QUIT_SP
            END

            --(Wan04) - END

            IF @n_PAToLocQty <= @n_QtyReceived
            BEGIN
               SET @n_PAInsertQty = @n_PAToLocQty
               SET @n_PAToLocQty = 0
               SET @n_LinePAQty = @n_LinePAQty + @n_PAInsertQty

               SET @c_ReceiptLineNumber = RIGHT ('00000' + CONVERT(NVARCHAR(5), CONVERT(INT, @c_ReceiptLineNumber) - 1), 5)
            END
            ELSE
            BEGIN
               SET @n_PAInsertQty = @n_QtyReceived
               SET @n_PAToLocQty = @n_PAToLocQty - @n_QtyReceived
               SET @n_LinePAQty = 0
            END

            IF @b_debug = 1
            BEGIN
               SELECT @n_LinePAQty '@n_LinePAQty'
                    , @n_QtyReceived '@n_QtyReceived'
                    , @n_PAInsertQty '@n_PAInsertQty'
                    , @c_FromLot '@c_FromLot'
                    , @c_FromLoc '@c_FromLoc'
                    , @c_FromID '@c_FromID'
                    , @c_SuggestLoc '@c_SuggestLoc'
                    , @n_PAToLocQty '@n_PAToLocQty'
                    , @n_SkuPKValue '@n_SkuPKValue'
                    , @n_PABookingKey '@n_PABookingKey'
            END

            SET @n_LoopCount = @n_PAInsertQty --WL01

            IF @n_PAInsertQty > 0
            BEGIN
               WHILE(@n_LoopCount > 0) --WL01
               BEGIN
                  BEGIN TRY
                     EXEC rdt.rdt_Putaway_PendingMoveIn 
                           @cUserName        = @c_UserName
                        ,  @cType            = 'LOCK' 
                        ,  @cStorerKey       = @c_Storerkey 
                        ,  @cSKu             = @c_Sku
                        ,  @cFromLOT         = @c_FromLot   
                        ,  @cFromLOC         = @c_FromLoc            
                        ,  @cFromID          = @c_FromID
                        ,  @cSuggestedLOC    = @c_SuggestLoc  
                        ,  @nPutawayQTY      = 1 --@n_PAInsertQty --WL01
                        ,  @nPABookingKey    = @n_PABookingKey OUTPUT
                        ,  @nErrNo           = @n_Err          OUTPUT
                        ,  @cErrMsg          = @c_ErrMsg       OUTPUT
                  END TRY
                  BEGIN CATCH
                     SET @n_Continue = 3
                     SET @n_Err = 63070
                     SET @c_ErrMsg = ERROR_MESSAGE()
                  
                     SET @c_ErrMsg = CONVERT(CHAR(5), @n_Err) + ': Error Executing rdt.rdt_Putaway_PendingMoveIn. Sku: ' + RTRIM(@c_Sku)
                                    + ' fail. <<' + @c_ErrMsg + '>>'
                  
                     GOTO QUIT_SP
                  END CATCH
                  
                  IF @b_debug = 1
                  BEGIN
                     SELECT @n_PABookingKey '@n_PABookingKey'
                          , @n_SkuQtyRemaining '@n_SkuQtyRemaining'
                  END
                  
                  IF EXISTS ( SELECT 1
                              FROM RECEIPTDETAIL WITH (NOLOCK)
                              WHERE ReceiptKey = @c_ReceiptKey
                              AND ReceiptLineNumber = @c_ReceiptLineUpdate
                              AND (UserDefine10 = '' OR UserDefine10 IS NULL) 
                            )
                  BEGIN
                     UPDATE RECEIPTDETAIL 
                     SET UserDefine10 = CONVERT(NVARCHAR(20), @n_PABookingKey)
                        ,EditWho = SUSER_SNAME()
                        ,EditDate= GETDATE()
                        ,TrafficCop = NULL
                     WHERE ReceiptKey = @c_ReceiptKey
                     AND ReceiptLineNumber = @c_ReceiptLineUpdate
                     AND (UserDefine10 = '' OR UserDefine10 IS NULL)
                  
                     IF @@ERROR <> 0 
                     BEGIN 
                        SET @n_Continue = 3
                        SET @n_Err = 63080
                        SET @c_ErrMsg = CONVERT(CHAR(5), @n_Err) + ': Error Update RECEIPTDETAIL Fail.'
                                      + '. (ispBatPA02)' 
                        GOTO QUIT_SP 
                     END  
                  END
               SET @n_LoopCount = @n_LoopCount - 1 --WL01
               END--End while (WL01)
            END
            IF @b_debug = 1
            BEGIN
               print 'end @c_SuggestLoc: ' + @c_SuggestLoc +', @n_PAToLocQty: ' + convert(char(5),@n_PAToLocQty) 
            END
         END--@n_PAToLocQty > 0

         IF @b_debug = 1
         BEGIN
            print 'end @nSkuQtyRemaining: ' + convert(char(5),@n_SkuQtyRemaining)
         END
      END--@nSkuQtyRemaining > 0
      
      SET @d_DateEnd = GETDATE()                       
                                                       
      SET @c_Step7 = CONVERT(NVARCHAR(10),DATEDIFF(ms, @d_DateStart, @d_DateEnd))        

      WHILE @@TRANCOUNT > 0 
      BEGIN 
         COMMIT TRAN
      END

      --(Wan01) - ENd
      SET @n_PickZoneCnt = 0
      SELECT @n_PickZoneCnt = COUNT(DISTINCT T.PickZone)
            ,@c_StrategyType= StrategyType
      FROM #t_PICKZONESUMM T
      WHERE T.Sku = @c_Sku
      AND T.StrategyType IN ('SKU', 'MATERIAL')
      GROUP BY T.StrategyType

      IF @n_PickZoneCnt > 1 
      BEGIN
         SET @c_SkuWarningMsg = @c_SkuWarningMsg + CASE WHEN @c_StrategyType = 'SKU' THEN 'Sku: ' + @c_Sku ELSE '' END + CHAR(13)
         SET @c_MaterialWarningMsg = @c_MaterialWarningMsg + CASE WHEN @c_StrategyType = 'MATERIAL' THEN 'ItemClass: ' + @c_ItemClass ELSE '' END + CHAR(13)
      END

      NEXT_SKU:         --(Wan01)
      IF @b_debug = 1
      BEGIN
         select 'FETCH NEXT RECORD: Current @c_Sku: ' + @c_Sku 
      END

      SET @d_SkuDateEnd = GETDATE()      
               
      --INSERT INTO TRACEINFO (TraceName, TimeIn, TimeOut, TotalTime, Step1, Step2, Step3, Step4, Step5, Col1, Col2, Col3, Col4, Col5)
      --VALUES ('ispBatPA02', @d_SkuDateStart, @d_SkuDateEnd, CONVERT(NVARCHAR(10), DATEDIFF(ms, @d_SkuDateStart, @d_SkuDateEnd))
      --       , @c_Step1, @c_Step2, @c_Step3, @c_Step4, @c_Step5, @c_Step6, @c_Step7, @c_receiptKey, @c_Sku, CONVERT(NVARCHAR(10), @n_PABookingKey))


      FETCH NEXT FROM @CUR_RDSKU INTO @c_Storerkey
                                    , @c_Sku
                                    , @c_SkuGroup  
                                    , @c_ItemClass 
                                    , @n_SkuQtyReceived  
   END
   CLOSE @CUR_RDSKU
   DEALLOCATE @CUR_RDSKU 
   
   --(Wan01) - START
   --IF @n_PABookingKey > 0
   --BEGIN
   --   UPDATE RECEIPT 
   --   SET UserDefine10 = @n_PABookingKey 
   --      ,EditWho = SUSER_NAME()
   --      ,EditDate= GETDATE()
   --      ,TrafficCop = NULL
   --   WHERE ReceiptKey = @c_ReceiptKey

   --   IF @@ERROR <> 0 
   --   BEGIN 
   --      SET @n_Continue = 3
   --      SET @n_Err = 63080
   --      SET @c_ErrMsg = CONVERT(CHAR(5), @n_Err) + ': Error Update RECEIPT Fail.'
   --                     + '. (ispBatPA02)' 
   --      GOTO QUIT_SP 
   --   END  
   --END 
   --(Wan01) - END
QUIT_SP:

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      --IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt  --(Wan01)
      IF  @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      --(Wan01) - START
      --ELSE
      --BEGIN
      --   WHILE @@TRANCOUNT > @n_StartTCnt
      --   BEGIN
      --      COMMIT TRAN
      --   END
      --END
      --(Wan01) - END
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispBatPA02'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END

      SET @c_ErrMsg = ''
      IF @c_SkuWarningMsg <> ''
         SET @c_ErrMsg = @c_ErrMsg + @c_SkuWarningMsg

      IF @c_MaterialWarningMsg <> ''
         SET @c_ErrMsg = @c_ErrMsg + @c_MaterialWarningMsg

      IF @c_ErrMsg <> ''
         SET @c_ErrMsg = 'PA Suggest Successful with Warning!! There Sku/Material with Multiple PickZone. ' + CHAR(13)
                       + @c_ErrMsg 
   END

   SET @d_ASNDateEnd = GETDATE()
   --INSERT INTO TRACEINFO (TraceName, TimeIn, TimeOut, TotalTime, Step1, Step2, Step3, Step4, Step5, Col1, Col2, Col3, Col4, Col5)
   --VALUES ('ispBatPA02', @d_ASNDateStart, @d_ASNDateEnd, CONVERT(NVARCHAR(10), DATEDIFF(ms, @d_ASNDateStart, @d_ASNDateEnd) )
   --       , '', '', '', '', '', '', '', @c_receiptKey, '', '')
   
   -- DROP TEMP TABLE
   --(Wan06) - START
   IF OBJECT_ID('tempdb..#t_PICKZONE','u') IS NOT NULL
   DROP TABLE #t_PICKZONE;

   IF OBJECT_ID('tempdb..#t_PICKZONESUMM','u') IS NOT NULL
   DROP TABLE #t_PICKZONESUMM;

   IF OBJECT_ID('tempdb..#t_MSKU','u') IS NOT NULL
   DROP TABLE #t_MSKU;
           
   IF OBJECT_ID('tempdb..#t_ZONE','u') IS NOT NULL
   DROP TABLE #t_ZONE;

   IF OBJECT_ID('tempdb..#T_LOC_HB','u') IS NOT NULL
   DROP TABLE #T_LOC_HB;

   IF OBJECT_ID('tempdb..#T_LOC_MZ','u') IS NOT NULL
   DROP TABLE #T_LOC_MZ;

   IF OBJECT_ID('tempdb..#T_LOC_FS','u') IS NOT NULL
   DROP TABLE #T_LOC_FS;
   --(Wan06) - END

   --(Wan01) - START
   IF @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
   --(Wan01) - END 
END -- procedure

GO