SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Stored Procedure: isp_GetDiscretePickTicketUSA_V5_1                        */
/* Creation Date: 10-Jul-2012                                                 */
/* Copyright: IDS                                                             */
/* Written by: YTWan                                                          */
/*                                                                            */
/* Purpose:  SOS#249590-IDSUS - Matrix PT for AFD.                            */
/*                                                                            */
/* Called By:  r_dw_consolidated_pick16_discrete_V5_1                         */
/*                                                                            */
/* PVCS Version: 1.0                                                          */
/*                                                                            */
/* Version: 5.4                                                               */
/*                                                                            */
/* Data Modifications:                                                        */
/*                                                                            */
/* Updates:                                                                   */
/* Date         Author     Ver   Purposes                                     */  
/* 01-AUG-2012  YTWan      1.1   Fixed. (Wan01)                               */ 
/* 02-Oct-2012  TLTING     1.2   Performance tune remove nvarchar             */
/******************************************************************************/

CREATE PROC [dbo].[isp_GetDiscretePickTicketUSA_V5_1] (
            @c_LoadKey  NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON      
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF   

   DECLARE  @b_debug          INT 

   DECLARE  @n_Continue       INT
         ,  @n_StartTCnt      INT
         ,  @b_Success        INT
         ,  @n_Err            INT
         ,  @c_Errmsg         NVARCHAR(255)

         ,  @c_ExecSQLStmt    NVARCHAR(MAX)
         ,  @c_ExecArguments  NVARCHAR(MAX)
      
         ,  @n_Cnt            INT

         ,  @n_SeqNo          INT
         ,  @c_PickHeaderKey  NVARCHAR(10)
         ,  @c_PickType       NVARCHAR(10)

         ,  @c_StorerKey      NVARCHAR(15)
         ,  @c_OrderKey       NVARCHAR(10)
         ,  @c_Lottable01     NVARCHAR(18)
         ,  @c_Loc            NVARCHAR(10) 
         ,  @c_Style          NVARCHAR(20) 
         ,  @c_Color          NVARCHAR(10) 
         ,  @c_Sku            NVARCHAR(20) 
         ,  @c_Size           NVARCHAR(5)     , @n_qty            INT
         ,  @c_Size1          NVARCHAR(5)     , @n_Qty1           INT          
         ,  @c_Size2          NVARCHAR(5)     , @n_Qty2           INT          
         ,  @c_Size3          NVARCHAR(5)     , @n_Qty3           INT          
         ,  @c_Size4          NVARCHAR(5)     , @n_Qty4           INT          
         ,  @c_Size5          NVARCHAR(5)     , @n_Qty5           INT          
         ,  @c_Size6          NVARCHAR(5)     , @n_Qty6           INT          
         ,  @c_Size7          NVARCHAR(5)     , @n_Qty7           INT          
         ,  @c_Size8          NVARCHAR(5)     , @n_Qty8           INT          
         ,  @c_Size9          NVARCHAR(5)     , @n_Qty9           INT          
         ,  @c_Size10         NVARCHAR(5)     , @n_Qty10          INT          
         ,  @c_Size11         NVARCHAR(5)     , @n_Qty11          INT    
         ,  @n_UnitPrice      FLOAT 
         ,  @n_OriginalQty    INT
         ,  @n_QtyAllocPicked INT

         ,  @b_NewSize        INT
         ,  @c_OrderkeyPrev   NVARCHAR(10)
         ,  @c_StylePrev      NVARCHAR(20)
         ,  @c_ColorPrev      NVARCHAR(10)
   SET @b_debug         = 0
   SET @n_Continue      = 1
   SET @n_StartTCnt     = @@TRANCOUNT
   SET @b_Success       = 1
   SET @c_Errmsg        = ''
   SET @c_ExecSQLStmt   = ''
   SET @c_ExecArguments = ''
   SET @n_Cnt           = 1
   SET @n_SeqNo         = 0
   SET @c_PickHeaderKey = ''
   SET @c_PickType      = ''
   SET @c_StorerKey     = ''
   SET @c_OrderKey      = ''
   SET @c_Lottable01    = ''
   SET @c_Loc           = ''
   SET @c_Style         = ''
   SET @c_Color         = ''
   SET @c_Sku           = ''
   SET @c_Size          = ''   SET @n_qty           = 0
   SET @c_Size1         = ''   SET @n_qty1          = 0        
   SET @c_Size1         = ''   SET @n_Qty1          = 0        
   SET @c_Size2         = ''   SET @n_Qty2          = 0        
   SET @c_Size3         = ''   SET @n_Qty3          = 0        
   SET @c_Size4         = ''   SET @n_Qty4          = 0        
   SET @c_Size5         = ''   SET @n_Qty5          = 0        
   SET @c_Size6         = ''   SET @n_Qty6          = 0        
   SET @c_Size7         = ''   SET @n_Qty7          = 0        
   SET @c_Size8         = ''   SET @n_Qty8          = 0        
   SET @c_Size9         = ''   SET @n_Qty9          = 0        
   SET @c_Size10        = ''   SET @n_Qty10         = 0        
   SET @c_Size11        = ''   SET @n_Qty11         = 0        
   SET @n_UnitPrice     = 0.00
   SET @n_OriginalQty   = 0
   SET @n_QtyAllocPicked= 0

   SET @b_NewSize       = 0
   SET @c_OrderkeyPrev  = ''
   SET @c_StylePrev     = ''
   SET @c_ColorPrev     = ''

   --(Wan01) - START
   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   --CREATE TABLE #ORDERQTY
   --           (  OrderKey       NVARCHAR(10)
   --           ,  OriginalQty    INT
   --           ,  QtyAllocPicked INT
   --           )
   --CREATE INDEX IX_ORDERQTY_Orderkey ON #ORDERQTY (Orderkey)


   CREATE TABLE #TMPORDER
               (  SeqNo          INT         NOT NULL IDENTITY(1,1)  PRIMARY KEY
               ,  PickSlipNo     NVARCHAR(10)
               ,  PickType       NVARCHAR(10)
               ,  Storerkey      NVARCHAR(15)
               ,  OrderKey       NVARCHAR(10)
               ,  OriginalQty    INT
               ,  QtyAllocPicked INT
               )
   --(Wan01) - END

   CREATE TABLE #TempDiscretePickSlip
               (  SeqNo          INT         NOT NULL IDENTITY(1,1)  PRIMARY KEY
               ,  PickSlipNo     NVARCHAR(10)
               ,  Storerkey      NVARCHAR(15)
               ,  OrderKey       NVARCHAR(10)
               ,  Loc            NVARCHAR(10) NULL
               ,  Style          NVARCHAR(20) NULL
               ,  Color          NVARCHAR(10) NULL
               ,  Lottable01     NVARCHAR(18) NULL  
               ,  UnitPrice      Float        NULL
               ,  Size1          NVARCHAR(5)  NULL     , Qty1        INT         NULL
               ,  Size2          NVARCHAR(5)  NULL     , Qty2        INT         NULL
               ,  Size3          NVARCHAR(5)  NULL     , Qty3        INT         NULL
               ,  Size4          NVARCHAR(5)  NULL     , Qty4        INT         NULL
               ,  Size5          NVARCHAR(5)  NULL     , Qty5        INT         NULL
               ,  Size6          NVARCHAR(5)  NULL     , Qty6        INT         NULL
               ,  Size7          NVARCHAR(5)  NULL     , Qty7        INT         NULL
               ,  Size8          NVARCHAR(5)  NULL     , Qty8        INT         NULL
               ,  Size9          NVARCHAR(5)  NULL     , Qty9        INT         NULL
               ,  Size10         NVARCHAR(5)  NULL     , Qty10       INT         NULL
               ,  Size11         NVARCHAR(5)  NULL     , Qty11       INT         NULL 
               )

   --(Wan01) - START
   --
   --CREATE TABLE #TempSize
   --           (  SeqNo       INT         NOT NULL IDENTITY(1,1)  PRIMARY KEY
   --           ,  Orderkey    NVARCHAR(10)
   --           ,  Loc         NVARCHAR(10)
   --           ,  Sku         NVARCHAR(20)
   --           ,  Style       NVARCHAR(20)
   --           ,  Color       NVARCHAR(10)
   --           ,  Size        NVARCHAR(5)
   --           ,  Qty         INT                
   --           )

   --INSERT INTO #ORDERQTY ( Orderkey,  OriginalQty, QtyAllocPicked )
   --SELECT OD.Orderkey
   --      ,OriginalQty   = ISNULL(SUM(OD.OriginalQty),0)
   --      ,QtyAllocPicked= ISNULL(SUM(OD.QtyAllocated + OD.QtyPicked),0)
   --FROM LOADPLANDETAIL LD WITH (NOLOCK)
   --JOIN ORDERDETAIL    OD WITH (NOLOCK) ON (LD.Orderkey=OD.Orderkey)
   --WHERE LD.Loadkey = @c_LoadKey
   --GROUP BY OD.Orderkey

   INSERT INTO #TMPORDER (Storerkey, Orderkey, PickSlipNo, PickType, OriginalQty, QtyAllocPicked)
   SELECT   DISTINCT 
            ISNULL(RTRIM(PICKDETAIL.Storerkey),'')
          , PICKDETAIL.OrderKey
          , ISNULL(RTRIM(PICKHEADER.PickHeaderKey),'')
          , ISNULL(RTRIM(PICKHEADER.PickType),'')
          , OriginalQty =(SELECT (ISNULL(SUM(OriginalQty),0)) FROM ORDERDETAIL WITH (NOLOCK) WHERE Orderkey = LOADPLANDETAIL.Orderkey)
          , QtyAllocPicked =(SELECT ISNULL(SUM(QtyAllocated + QtyPicked),0) FROM ORDERDETAIL WITH (NOLOCK) WHERE Orderkey = LOADPLANDETAIL.Orderkey)
   FROM LOADPLANDETAIL WITH (NOLOCK)  
   JOIN PICKDETAIL     WITH (NOLOCK) ON (LOADPLANDETAIL.OrderKey = PICKDETAIL.OrderKey)
   JOIN SKU            WITH (NOLOCK) ON (PICKDETAIL.StorerKey = SKU.StorerKey AND PICKDETAIL.Sku = SKU.Sku)
   LEFT JOIN PICKHEADER WITH (NOLOCK)ON (LOADPLANDETAIL.OrderKey = PICKHEADER.Orderkey) AND (Zone = 'D')      --(Wan01)
   WHERE LOADPLANDETAIL.LoadKey = @c_LoadKey
   AND PICKDETAIL.Status < '9' 
   ORDER BY ISNULL(RTRIM(PICKDETAIL.Storerkey),'')
          , PICKDETAIL.OrderKey  

   DECLARE ORDERS_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT   ISNULL(RTRIM(Storerkey),'')
          , ISNULL(RTRIM(OrderKey),'')
          , ISNULL(RTRIM(PickSlipNo),'')
          , ISNULL(RTRIM(PickType),'')
   FROM #TMPORDER
   ORDER BY SeqNo
   --(Wan01) - END

   OPEN ORDERS_CUR
   FETCH NEXT FROM ORDERS_CUR INTO @c_Storerkey, @c_OrderKey
                                 , @c_PickHeaderKey                                                            --(Wan01)
                                 , @c_PickType                                                                 --(Wan01)
   
   WHILE (@@FETCH_STATUS <> -1)
   BEGIN 
      IF @c_PickHeaderKey = ''
      BEGIN
         EXECUTE nspg_GetKey
                 'PICKSLIP' 
               , 9 
               , @c_PickHeaderKey   OUTPUT 
               , @b_Success         OUTPUT 
               , @n_Err             OUTPUT 
               , @c_Errmsg          OUTPUT

 
         SET @c_PickHeaderKey = 'P' + @c_PickHeaderKey

         BEGIN TRAN
         IF @b_debug = 1
         BEGIN
            SELECT 'Insert PickHeader in progress, @c_PickHeaderKey: ', @c_PickHeaderKey
         END 

         INSERT INTO PICKHEADER (PickHeaderKey, ExternOrderKey, Orderkey, PickType, Zone, TrafficCop)
         VALUES (@c_PickHeaderKey, @c_LoadKey, @c_OrderKey, '0', 'D', '')

         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_err = 30101  
            SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Error Insert PICKHEADER. (isp_GetDiscretePickTicketUSA_V5_1)' 
            GOTO QUIT
         END

         UPDATE PICKDETAIL WITH (ROWLOCK)
         SET   PickSlipNo = @c_PickHeaderKey  
            ,  Trafficcop = NULL
         WHERE Orderkey = @c_OrderKey
         AND   Status < '9'  
         AND   (RTRIM(PickSlipNo) = '' OR PickSlipNo IS NULL)

         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_err = 30102  
            SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Error Update PICKDETAIL. (isp_GetDiscretePickTicketUSA_V5_1)' 
            GOTO QUIT
         END
      END
      ELSE
      BEGIN
         IF @c_PickType = '0'  
         BEGIN
            BEGIN TRAN

            UPDATE PICKHEADER WITH (ROWLOCK)
            SET   PickType = '1' 
               ,  TrafficCop = NULL
            WHERE PickHeaderKey = @c_PickHeaderKey --@c_OrderKey                                                       --(Wan01)
            AND Zone = 'D'
            AND PickType = '0'

            SET @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SET @n_continue = 3
               SET @n_err = 30104  
               SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Error Update PICKHEADER. (isp_GetDiscretePickTicketUSA_V5_1)' 
               GOTO QUIT
            END
         END
      END

      WHILE @@TRANCOUNT > 0
      BEGIN
         COMMIT TRAN
      END
--(Wan01) - START
      FETCH NEXT FROM ORDERS_CUR INTO @c_Storerkey, @c_OrderKey
                                    , @c_PickHeaderKey                                                          
                                    , @c_PickType                                                       
   END 
   CLOSE ORDERS_CUR
   DEALLOCATE ORDERS_CUR

   DECLARE LOCxSTYLExCOLOR_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT ISNULL(RTRIM(TSO.PickSlipNo),'')
         ,ISNULL(RTRIM(TSO.Storerkey),'')
         ,ISNULL(RTRIM(TSO.Orderkey),'')
         ,Loc = (SELECT TOP 1 RTRIM(P.Loc) FROM PICKDETAIL P WITH (NOLOCK) 
                                           WHERE P.Orderkey = ISNULL(RTRIM(TSO.ORderkey),'')
                                           AND   P.Storerkey= ISNULL(RTRIM(TSO.Storerkey),'') 
                                           AND   P.Sku      = ISNULL(RTRIM(SKU.Sku),'')) 
         ,Lottable01 = (SELECT TOP 1 RTRIM(OD.Lottable01) FROM ORDERDETAIL OD WITH (NOLOCK) 
                                                          WHERE OD.Orderkey = ISNULL(RTRIM(TSO.ORderkey),'')
                                                          AND   OD.Storerkey= ISNULL(RTRIM(TSO.Storerkey),'') 
                                                          AND   OD.Sku      = ISNULL(RTRIM(SKU.Sku),'')) 
         ,UnitPrice  = (SELECT TOP 1 ISNULL(OD.UnitPrice,0.00) FROM ORDERDETAIL OD WITH (NOLOCK) 
                                                               WHERE OD.Orderkey = ISNULL(RTRIM(TSO.ORderkey),'')
                                                               AND   OD.Storerkey= ISNULL(RTRIM(TSO.Storerkey),'') 
                                                               AND   OD.Sku      = ISNULL(RTRIM(SKU.Sku),'')) 

         ,ISNULL(RTRIM(SKU.Style),'')
         ,ISNULL(RTRIM(SKU.Color),'')
         ,ISNULL(RTRIM(SKU.Size),'')
         ,ISNULL(RTRIM(SKU.SKU),'')
         ,ISNULL(SUM(PD.Qty),0)
   FROM #TMPORDER  TSO
   JOIN PICKDETAIL PD  WITH (NOLOCK) ON (TSO.Orderkey = PD.Orderkey)
   JOIN SKU        SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.Sku = SKU.Sku)
   GROUP BY ISNULL(RTRIM(TSO.PickSlipNo),'')
         ,  ISNULL(RTRIM(TSO.Storerkey),'')
         ,  ISNULL(RTRIM(TSO.Orderkey),'')
         ,  ISNULL(RTRIM(SKU.Style),'')
         ,  ISNULL(RTRIM(SKU.Color),'')
         ,  ISNULL(RTRIM(SKU.Size),'')
         ,  ISNULL(RTRIM(SKU.SKU),'')
   ORDER BY ISNULL(RTRIM(TSO.Storerkey),'')
         ,  ISNULL(RTRIM(TSO.Orderkey),'')
         ,  ISNULL(RTRIM(SKU.Style),'')
         ,  ISNULL(RTRIM(SKU.Color),'')
         ,  ISNULL(RTRIM(SKU.SKU),'')

   OPEN LOCxSTYLExCOLOR_CUR
   FETCH NEXT FROM LOCxSTYLExCOLOR_CUR INTO @c_PickHeaderKey
                                          , @c_Storerkey
                                          , @c_Orderkey
                                          , @c_Loc
                                          , @c_Lottable01
                                          , @n_UnitPrice
                                          , @c_Style
                                          , @c_Color
                                          , @c_Size
                                          , @c_Sku
                                          , @n_Qty

   WHILE (@@FETCH_STATUS <> -1)
   BEGIN
      SET @b_NewSize = 0

      IF @c_Orderkey = @c_OrderkeyPrev AND @c_Style = @c_StylePrev AND @c_Color = @c_ColorPrev  
      BEGIN
         IF @c_Size1 = @c_Size
         BEGIN
            SET @n_Qty1 = @n_Qty1 + @n_Qty
         END
         ELSE
         IF @c_Size2 = @c_Size
         BEGIN
            SET @n_Qty2 = @n_Qty2 + @n_Qty
         END
         ELSE
         IF @c_Size3 = @c_Size
         BEGIN
            SET @n_Qty3 = @n_Qty3 + @n_Qty
         END
         ELSE
         IF @c_Size4 = @c_Size
         BEGIN
            SET @n_Qty4 = @n_Qty4 + @n_Qty
         END
         ELSE
         IF @c_Size5 = @c_Size
         BEGIN
            SET @n_Qty5 = @n_Qty5 + @n_Qty
         END
         ELSE
         IF @c_Size6 = @c_Size
         BEGIN
            SET @n_Qty6 = @n_Qty6 + @n_Qty
         END
         ELSE
         IF @c_Size7 = @c_Size
         BEGIN
            SET @n_Qty7 = @n_Qty7 + @n_Qty
         END
         ELSE
         IF @c_Size8 = @c_Size
         BEGIN
            SET @n_Qty8 = @n_Qty8 + @n_Qty
         END
         ELSE
         IF @c_Size9 = @c_Size
         BEGIN
            SET @n_Qty9 = @n_Qty9 + @n_Qty
         END
         ELSE
         IF @c_Size10 = @c_Size
         BEGIN
            SET @n_Qty10 = @n_Qty10 + @n_Qty
         END
         ELSE
         IF @c_Size11 = @c_Size
         BEGIN
            SET @n_Qty11 = @n_Qty11 + @n_Qty
         END
         ELSE
         BEGIN
            SET @b_NewSize = 1 
         END
      END
      ELSE
      BEGIN 
         INSERT INTO #TempDiscretePickSlip (PickSlipNo, Storerkey, Orderkey, Loc, Lottable01, UnitPrice, Style, Color)
         VALUES (@c_PickHeaderKey, @c_Storerkey, @c_Orderkey, @c_Loc, @c_Lottable01, @n_UnitPrice, @c_Style, @c_Color)

         SET @n_SeqNo = @@identity

         SET @b_NewSize = 1
      END

      IF @b_NewSize = 1 
      BEGIN
         SET @c_ExecSQLStmt = N'SET @c_Size'+RTRIM(CONVERT(VARCHAR(2),@n_Cnt))+'=@c_Size' 
                            + ' SET @n_Qty' +RTRIM(CONVERT(VARCHAR(2),@n_Cnt))+'=@n_Qty'  

         SET @c_ExecArguments = N'@c_Size    NVARCHAR(5)           ,@n_Qty     INT'    
                              + ',@c_Size1   NVARCHAR(5)  OUTPUT   ,@n_Qty1    INT   OUTPUT'  
                              + ',@c_Size2   NVARCHAR(5)  OUTPUT   ,@n_Qty2    INT   OUTPUT'  
                              + ',@c_Size3   NVARCHAR(5)  OUTPUT   ,@n_Qty3    INT   OUTPUT'  
                              + ',@c_Size4   NVARCHAR(5)  OUTPUT   ,@n_Qty4    INT   OUTPUT' 
                              + ',@c_Size5   NVARCHAR(5)  OUTPUT   ,@n_Qty5    INT   OUTPUT'  
                              + ',@c_Size6   NVARCHAR(5)  OUTPUT   ,@n_Qty6    INT   OUTPUT' 
                              + ',@c_Size7   NVARCHAR(5)  OUTPUT   ,@n_Qty7    INT   OUTPUT'  
                              + ',@c_Size8   NVARCHAR(5)  OUTPUT   ,@n_Qty8    INT   OUTPUT' 
                              + ',@c_Size9   NVARCHAR(5)  OUTPUT   ,@n_Qty9    INT   OUTPUT' 
                              + ',@c_Size10  NVARCHAR(5)  OUTPUT   ,@n_Qty10   INT   OUTPUT'  
                              + ',@c_Size11  NVARCHAR(5)  OUTPUT   ,@n_Qty11   INT   OUTPUT'          


         EXEC sp_ExecuteSql @c_ExecSQLStmt             
                          , @c_ExecArguments             
                          , @c_Size          , @n_Qty 
                          , @c_Size1  OUTPUT , @n_Qty1   OUTPUT
                          , @c_Size2  OUTPUT , @n_Qty2   OUTPUT
                          , @c_Size3  OUTPUT , @n_Qty3   OUTPUT   
                          , @c_Size4  OUTPUT , @n_Qty4   OUTPUT   
                          , @c_Size5  OUTPUT , @n_Qty5   OUTPUT   
                          , @c_Size6  OUTPUT , @n_Qty6   OUTPUT
                          , @c_Size7  OUTPUT , @n_Qty7   OUTPUT
                          , @c_Size8  OUTPUT , @n_Qty8   OUTPUT
                          , @c_Size9  OUTPUT , @n_Qty9   OUTPUT
                          , @c_Size10 OUTPUT , @n_Qty10  OUTPUT
                          , @c_Size11 OUTPUT , @n_Qty11  OUTPUT

         SET @n_Cnt = @n_Cnt + 1
      END

      UPDATE #TempDiscretePickSlip
      SET Style   = @c_Style
         ,Color   = @c_Color
         ,Size1 	= @c_Size1 	, Qty1   = @n_Qty1      
      	,Size2 	= @c_Size2 	, Qty2   = @n_Qty2      
      	,Size3 	= @c_Size3 	, Qty3   = @n_Qty3      
      	,Size4 	= @c_Size4 	, Qty4   = @n_Qty4      
      	,Size5 	= @c_Size5 	, Qty5   = @n_Qty5      
      	,Size6 	= @c_Size6 	, Qty6   = @n_Qty6      
      	,Size7 	= @c_Size7 	, Qty7   = @n_Qty7      
      	,Size8 	= @c_Size8 	, Qty8   = @n_Qty8      
      	,Size9 	= @c_Size9 	, Qty9   = @n_Qty9      
      	,Size10	= @c_Size10	, Qty10  = @n_Qty10     
      	,Size11	= @c_Size11	, Qty11  = @n_Qty11
      WHERE SeqNo = @n_SeqNo

      SET @c_OrderkeyPrev = @c_Orderkey
      SET @c_StylePrev = @c_Style
      SET @c_ColorPrev = @c_Color
  
      FETCH NEXT FROM LOCxSTYLExCOLOR_CUR INTO @c_PickHeaderKey
                                             , @c_Storerkey
                                             , @c_Orderkey
                                             , @c_Loc
                                             , @c_Lottable01
                                             , @n_UnitPrice
                                             , @c_Style
                                             , @c_Color
                                             , @c_Size
                                             , @c_Sku
                                             , @n_Qty

      IF @c_Orderkey <> @c_OrderkeyPrev OR @c_Style <> @c_StylePrev OR @c_Color <> @c_ColorPrev 
      BEGIN
         SET @n_Cnt = 1
         SET @c_Size1         = ''   SET @n_Qty1          = 0        
         SET @c_Size1         = ''   SET @n_Qty1          = 0        
         SET @c_Size2         = ''   SET @n_Qty2          = 0        
         SET @c_Size3         = ''   SET @n_Qty3          = 0        
         SET @c_Size4         = ''   SET @n_Qty4          = 0        
         SET @c_Size5         = ''   SET @n_Qty5          = 0        
         SET @c_Size6         = ''   SET @n_Qty6          = 0        
         SET @c_Size7         = ''   SET @n_Qty7          = 0        
         SET @c_Size8         = ''   SET @n_Qty8          = 0        
         SET @c_Size9         = ''   SET @n_Qty9          = 0        
         SET @c_Size10        = ''   SET @n_Qty10         = 0        
         SET @c_Size11        = ''   SET @n_Qty11         = 0  
      END
   END
   CLOSE LOCxSTYLExCOLOR_CUR
   DEALLOCATE LOCxSTYLExCOLOR_CUR
    

--      DECLARE LOCxSTYLExCOLOR_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
--      SELECT DISTINCT 
--             ISNULL(RTRIM(SKU.Style),'')
--          ,  ISNULL(RTRIM(SKU.Color),'')
--      FROM ORDERDETAIL WITH (NOLOCK)
--      JOIN SKU         WITH (NOLOCK) ON (ORDERDETAIL.StorerKey = SKU.StorerKey AND ORDERDETAIL.Sku = SKU.Sku)
--      WHERE ORDERDETAIL.Orderkey = @c_OrderKey
--      ORDER BY ISNULL(RTRIM(SKU.Style),'')
--             , ISNULL(RTRIM(SKU.Color),'')
--
--      OPEN LOCxSTYLExCOLOR_CUR
--      FETCH NEXT FROM LOCxSTYLExCOLOR_CUR INTO @c_Style
--                                             , @c_Color
--
--      WHILE (@@FETCH_STATUS <> -1)
--      BEGIN
----         SELECT TOP 1 @c_Loc        = RTRIM(PICKDETAIL.Loc)
----                     ,@c_Lottable01 = RTRIM(ORDERDETAIL.Lottable01)
----                     ,@n_UnitPrice  = ISNULL(ORDERDETAIL.UnitPrice,0.00)
----         FROM ORDERDETAIL WITH (NOLOCK)
----         JOIN PICKDETAIL  WITH (NOLOCK) ON (ORDERDETAIL.OrderKey = PICKDETAIL.OrderKey)
----                                        AND(ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderLineNumber)
----         JOIN SKU         WITH (NOLOCK) ON (PICKDETAIL.StorerKey = SKU.StorerKey AND PICKDETAIL.Sku = SKU.Sku)
----         WHERE PICKDETAIL.Orderkey = @c_Orderkey
----         AND   SKU.Style = @c_Style
----         AND   SKU.Color = @c_Color
--
--         TRUNCATE TABLE #TempSize
--
--         INSERT INTO #TempSize (Orderkey, Loc, Sku, Style, Color, Size, Qty)
--         SELECT @c_Orderkey
--               ,@c_Loc
--               ,@c_Style
--               ,@c_Color
--               ,ISNULL(MIN(RTRIM(SKU.SKU)),'')
--               ,ISNULL(RTRIM(SKU.Size),'')
--               ,ISNULL(SUM(PICKDETAIL.Qty),0)
--         FROM PICKDETAIL  WITH (NOLOCK) 
--         JOIN SKU         WITH (NOLOCK) ON (PICKDETAIL.StorerKey = SKU.StorerKey AND PICKDETAIL.Sku = SKU.Sku)
--         WHERE PICKDETAIL.Orderkey = @c_Orderkey
--         AND   SKU.Style = @c_Style
--         AND   SKU.Color = @c_Color
--         GROUP BY ISNULL(RTRIM(SKU.Size),'')
--
--         SET @n_Cnt = 1
--         SET @c_Size1         = ''   SET @n_qty1          = 0        
--         SET @c_Size1         = ''   SET @n_Qty1          = 0        
--         SET @c_Size2         = ''   SET @n_Qty2          = 0        
--         SET @c_Size3         = ''   SET @n_Qty3          = 0        
--         SET @c_Size4         = ''   SET @n_Qty4          = 0        
--         SET @c_Size5         = ''   SET @n_Qty5          = 0        
--         SET @c_Size6         = ''   SET @n_Qty6          = 0        
--         SET @c_Size7         = ''   SET @n_Qty7          = 0        
--         SET @c_Size8         = ''   SET @n_Qty8          = 0        
--         SET @c_Size9         = ''   SET @n_Qty9          = 0        
--         SET @c_Size10        = ''   SET @n_Qty10         = 0        
--         SET @c_Size11        = ''   SET @n_Qty11         = 0  
--
--         -- Need to Sort by SKU
--         DECLARE SIZE_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
--         --(Wan01) - START
--         --  SELECT DISTINCT 
--         --         ISNULL(RTRIM(SKU.Sku),'')
--         --        ,ISNULL(RTRIM(SKU.Size),'')
--         --  FROM PICKDETAIL  WITH (NOLOCK) 
--         --  JOIN SKU         WITH (NOLOCK) ON (PICKDETAIL.StorerKey = SKU.StorerKey AND PICKDETAIL.Sku = SKU.Sku)
--         --  WHERE PICKDETAIL.Orderkey = @c_Orderkey
--         --  AND   SKU.Style = @c_Style
--         --  AND   SKU.Color = @c_Color
--         --  ORDER BY ISNULL(RTRIM(SKU.Sku),'')
--         SELECT TS.Size
--         FROM #TempSize TS
--         ORDER BY TS.Sku
--         --(Wan01) - END
--         
--
--         OPEN SIZE_CUR
--         FETCH NEXT FROM SIZE_CUR INTO @c_Size
--
--         WHILE (@@FETCH_STATUS <> -1) 
--         BEGIN
--            --(Wan01) - START
--            --IF EXISTS (SELECT 1 
--            --           FROM #TempSize
--            --           WHERE Orderkey = @c_Orderkey
--            --           AND   Loc   = @c_Loc
--            --           AND   Style = @c_Style
--            --           AND   Color = @c_Color
--            --           AND   Size  = @c_Size)
--            --BEGIN
--            --   GOTO NEXT_SIZE
--            --END
--            --(Wan01) - END
--
--            IF @n_Cnt >= 12 
--            BEGIN
--               BREAK
--            END
--
--            --(Wan01) - START
--            --SELECT @n_Qty = ISNULL(SUM(PICKDETAIL.Qty),0)
--            --FROM PICKDETAIL  WITH (NOLOCK) 
--            --JOIN SKU         WITH (NOLOCK) ON (PICKDETAIL.StorerKey = SKU.StorerKey AND PICKDETAIL.Sku = SKU.Sku)
--            --WHERE PICKDETAIL.Orderkey = @c_Orderkey
--            --AND   SKU.Style = @c_Style
--            --AND   SKU.Color = @c_Color
--            --AND   SKU.Size  = @c_Size
--            --(Wan01) - END
--
--            SET @c_ExecSQLStmt = N'SET @c_Size'+RTRIM(CONVERT(VARCHAR(2),@n_Cnt))+'=@c_Size' 
--                               + ' SET @n_Qty' +RTRIM(CONVERT(VARCHAR(2),@n_Cnt))+'=@n_qty'  
--
--            SET @c_ExecArguments = N'@c_Size    NVARCHAR(5)           ,@n_Qty     INT'    
--                                 + ',@c_Size1   NVARCHAR(5)  OUTPUT   ,@n_Qty1    INT   OUTPUT'  
--                                 + ',@c_Size2   NVARCHAR(5)  OUTPUT   ,@n_Qty2    INT   OUTPUT'  
--                                 + ',@c_Size3   NVARCHAR(5)  OUTPUT   ,@n_Qty3    INT   OUTPUT'  
--                                 + ',@c_Size4   NVARCHAR(5)  OUTPUT   ,@n_Qty4    INT   OUTPUT' 
--                                 + ',@c_Size5   NVARCHAR(5)  OUTPUT   ,@n_Qty5    INT   OUTPUT'  
--                                 + ',@c_Size6   NVARCHAR(5)  OUTPUT   ,@n_Qty6    INT   OUTPUT' 
--                                 + ',@c_Size7   NVARCHAR(5)  OUTPUT   ,@n_Qty7    INT   OUTPUT'  
--                                 + ',@c_Size8   NVARCHAR(5)  OUTPUT   ,@n_Qty8    INT   OUTPUT' 
--                                 + ',@c_Size9   NVARCHAR(5)  OUTPUT   ,@n_Qty9    INT   OUTPUT' 
--                                 + ',@c_Size10  NVARCHAR(5)  OUTPUT   ,@n_Qty10   INT   OUTPUT'  
--                                 + ',@c_Size11  NVARCHAR(5)  OUTPUT   ,@n_Qty11   INT   OUTPUT'          
--
-- 
--            EXEC sp_ExecuteSql @c_ExecSQLStmt             
--                             , @c_ExecArguments             
--                             , @c_Size          , @n_Qty 
--                             , @c_Size1  OUTPUT , @n_qty1   OUTPUT
--                             , @c_Size2  OUTPUT , @n_qty2   OUTPUT
--                             , @c_Size3  OUTPUT , @n_qty3   OUTPUT   
--                             , @c_Size4  OUTPUT , @n_qty4   OUTPUT   
--                             , @c_Size5  OUTPUT , @n_qty5   OUTPUT   
--                             , @c_Size6  OUTPUT , @n_qty6   OUTPUT
--                             , @c_Size7  OUTPUT , @n_qty7   OUTPUT
--                             , @c_Size8  OUTPUT , @n_qty8   OUTPUT
--                             , @c_Size9  OUTPUT , @n_qty9   OUTPUT
--                             , @c_Size10 OUTPUT , @n_qty10  OUTPUT
--                             , @c_Size11 OUTPUT , @n_qty11  OUTPUT
--    
--            --(Wan01) -START
--            --INSERT INTO #TempSize (Orderkey, Loc, Style, Color, Size)
--            --VALUES (@c_Orderkey, @c_Loc, @c_Style, @c_Color, @c_Size)
--
--            --SET @n_err = @@ERROR
--            --IF @n_err <> 0
--            --BEGIN
--            --   SET @n_continue = 3
--            --   SET @n_err = 30105
--            --   SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Error Insert #TempSize. (isp_GetDiscretePickTicketUSA_V5_1)' 
--            --   GOTO QUIT
--            --END
--            --(Wan01) -END
--
--            SET @n_Cnt = @n_Cnt + 1
--  
--            NEXT_SIZE:
--            FETCH NEXT FROM SIZE_CUR INTO @c_Size
--         END
--         CLOSE SIZE_CUR
--         DEALLOCATE SIZE_CUR
--
--         INSERT INTO #TempDiscretePickSlip
--                     ( PickSlipNo
--                     , OrderKey   
--                     , Loc
--                     , Style
--                     , Color
--                     , Lottable01
--                     , UnitPrice
--                     , Size1  , qty1
--                     , Size2  , qty2
--                     , Size3  , qty3
--                     , Size4  , qty4
--                     , Size5  , qty5
--                     , Size6  , qty6
--                     , Size7  , qty7
--                     , Size8  , qty8
--                     , Size9  , qty9
--                     , Size10 , qty10
--                     , Size11 , qty11       
--                     )
--         VALUES      ( @c_PickHeaderkey
--                     , @c_Orderkey
--                     , @c_Loc
--                     , @c_Style
--                     , @c_Color
--                     , @c_Lottable01
--                     , @n_UnitPrice
--                     , @c_Size1  , @n_qty1
--                     , @c_Size2  , @n_qty2
--                     , @c_Size3  , @n_qty3
--                     , @c_Size4  , @n_qty4
--                     , @c_Size5  , @n_qty5
--                     , @c_Size6  , @n_qty6
--                     , @c_Size7  , @n_qty7
--                     , @c_Size8  , @n_qty8
--                     , @c_Size9  , @n_qty9
--                     , @c_Size10 , @n_qty10 
--                     , @c_Size11 , @n_qty11 
--                     )
--
--         SET @n_err = @@ERROR
--         IF @n_err <> 0
--         BEGIN
--            SET @n_continue = 3
--            SET @n_err = 30106
--            SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Error Insert #TempDiscretePickSlip. (isp_GetDiscretePickTicketUSA_V5_1)' 
--            GOTO QUIT
--         END
--
--         FETCH NEXT FROM LOCxSTYLExCOLOR_CUR INTO @c_Style
--                                                , @c_Color
--      END
--      CLOSE LOCxSTYLExCOLOR_CUR
--      DEALLOCATE LOCxSTYLExCOLOR_CUR
--
--      FETCH NEXT FROM ORDERS_CUR INTO @c_Storerkey, @c_OrderKey
--                                    , @c_PickHeaderKey                                                         --(Wan01)
--                                    , @n_OriginalQty                                                           --(Wan01)
--                                    , @n_QtyAllocPicked                                                        --(Wan01)
--   END 
--   CLOSE ORDERS_CUR
--   DEALLOCATE ORDERS_CUR
--(Wan01) - END
   QUIT:
   IF CURSOR_STATUS('LOCAL' , 'ORDERS_CUR') in (0 , 1)
   BEGIN
      CLOSE ORDERS_CUR
      DEALLOCATE ORDERS_CUR
   END

   IF CURSOR_STATUS('LOCAL' , 'LOCxSTYLExCOLOR_CUR') in (0 , 1)
   BEGIN
      CLOSE LOCxSTYLExCOLOR_CUR
      DEALLOCATE LOCxSTYLExCOLOR_CUR
   END
   
   --(Wan01) - START
   --
   --IF CURSOR_STATUS('LOCAL' , 'SIZE_CUR') in (0 , 1)
   --BEGIN
   --   CLOSE SIZE_CUR
   --   DEALLOCATE SIZE_CUR
   --END
   --(Wan01) - END

   SELECT   OH_LoadKey        = @c_LoadKey                                                    
         ,  ST_Company        = ISNULL(RTRIM(STORER.Company),'')                                                           
         ,  OH_Storerkey      = ISNULL(RTRIM(ORDERS.Storerkey),'')   
         ,  FAC_Descr         = ISNULL(RTRIM(FACILITY.Descr),'')
         ,  FAC_UDF01         = ISNULL(RTRIM(FACILITY.UserDefine01),'')
         ,  FAC_UDF03         = ISNULL(RTRIM(FACILITY.UserDefine03),'')
         ,  FAC_UDF04         = ISNULL(RTRIM(FACILITY.UserDefine04),'')
         ,  #TempDiscretePickSlip.PickSlipNo                                      
         ,  OH_Orderkey       = ORDERS.Orderkey                                      
         ,  OH_ExternOrderkey = ISNULL(RTRIM(ORDERS.ExternOrderkey),'')   
         ,  OH_OrderDate      = ORDERS.OrderDate      
         ,  OH_DeliveryDate   = ORDERS.DeliveryDate   
         ,  OH_EffectiveDate  = ORDERS.EffectiveDate  
         ,  OH_ConsigneeKey   = ISNULL(RTRIM(ORDERS.ConsigneeKey),'')  
         ,  OH_C_Company      = ISNULL(RTRIM(ORDERS.C_Company),'')                                                   
         ,  OH_C_Address1     = ISNULL(RTRIM(ORDERS.C_Address1),'') 
         ,  OH_C_Address2     = ISNULL(RTRIM(ORDERS.C_Address2),'') 
         ,  OH_C_Address3     = ISNULL(RTRIM(ORDERS.C_Address3),'') 
         ,  OH_C_Address4     = ISNULL(RTRIM(ORDERS.C_Address4),'') 
         ,  OH_C_City         = ISNULL(RTRIM(ORDERS.C_City),'')     
         ,  OH_C_State        = ISNULL(RTRIM(ORDERS.C_State),'')    
         ,  OH_C_Zip          = ISNULL(RTRIM(ORDERS.C_Zip),'')                                                           
         ,  OH_C_Country      = ISNULL(RTRIM(ORDERS.C_Country),'')                                                        
         ,  OH_MarkforKey     = ISNULL(RTRIM(ORDERS.MarkforKey),'')                                                      
         ,  OH_M_Company      = ISNULL(RTRIM(ORDERS.M_Company),'')                                                       
         ,  OH_M_Address1     = ISNULL(RTRIM(ORDERS.M_Address1),'') 
         ,  OH_M_Address2     = ISNULL(RTRIM(ORDERS.M_Address2),'') 
         ,  OH_M_Address3     = ISNULL(RTRIM(ORDERS.M_Address3),'') 
         ,  OH_M_Address4     = ISNULL(RTRIM(ORDERS.M_Address4),'') 
         ,  OH_M_City         = ISNULL(RTRIM(ORDERS.M_City),'')     
         ,  OH_M_State        = ISNULL(RTRIM(ORDERS.M_State),'')    
         ,  OH_M_Zip          = ISNULL(RTRIM(ORDERS.M_Zip),'')                                                           
         ,  OH_M_Country      = ISNULL(RTRIM(ORDERS.M_Country),'')                                                                
         ,  OH_BuyerPO        = ISNULL(RTRIM(ORDERS.BuyerPO),'')                                                         
         ,  OH_UserDefine03   = ISNULL(RTRIM(ORDERS.UserDefine03),'')
         ,  ORDER_OriginalQty = #TMPORDER.OriginalQty   
         ,  ORDER_QTYAllocQty = #TMPORDER.QtyAllocPicked                                                      
         ,  OH_NOTES_1        = SUBSTRING(CONVERT(VARCHAR(1000), ORDERS.Notes),   1,250)  
         ,  OH_NOTES_2        = SUBSTRING(CONVERT(VARCHAR(1000), ORDERS.Notes), 251,250)   
         ,  OH_NOTES_3        = SUBSTRING(CONVERT(VARCHAR(1000), ORDERS.Notes), 501,250)   
         ,  OH_NOTES_4        = SUBSTRING(CONVERT(VARCHAR(1000), ORDERS.Notes), 751,250)                               
         ,  OH_NOTES2         = SUBSTRING(CONVERT(VARCHAR(1000), ORDERS.Notes2),  1,250)  
         ,  OH_NOTES2_2       = SUBSTRING(CONVERT(VARCHAR(1000), ORDERS.Notes2),251,250)   
         ,  OH_NOTES2_3       = SUBSTRING(CONVERT(VARCHAR(1000), ORDERS.Notes2),501,250)   
         ,  OH_NOTES2_4       = SUBSTRING(CONVERT(VARCHAR(1000), ORDERS.Notes2),751,250) 
         ,  #TempDiscretePickSlip.Loc                                              
         ,  #TempDiscretePickSlip.Style                                            
         ,  #TempDiscretePickSlip.Color                                            
         ,  #TempDiscretePickSlip.Lottable01 
         ,  #TempDiscretePickSlip.UnitPrice                                         
         ,  #TempDiscretePickSlip.Size1                                            
         ,  #TempDiscretePickSlip.Qty1                                             
         ,  #TempDiscretePickSlip.Size2                                            
         ,  #TempDiscretePickSlip.Qty2                                             
         ,  #TempDiscretePickSlip.Size3                                            
         ,  #TempDiscretePickSlip.Qty3                                             
         ,  #TempDiscretePickSlip.Size4                                            
         ,  #TempDiscretePickSlip.Qty4                                             
         ,  #TempDiscretePickSlip.Size5                                            
         ,  #TempDiscretePickSlip.Qty5                                             
         ,  #TempDiscretePickSlip.Size6                                            
         ,  #TempDiscretePickSlip.Qty6                                             
         ,  #TempDiscretePickSlip.Size7                                            
         ,  #TempDiscretePickSlip.Qty7                                             
         ,  #TempDiscretePickSlip.Size8                                            
         ,  #TempDiscretePickSlip.Qty8                                             
         ,  #TempDiscretePickSlip.Size9                                            
         ,  #TempDiscretePickSlip.Qty9                                             
         ,  #TempDiscretePickSlip.Size10                                           
         ,  #TempDiscretePickSlip.Qty10                                            
         ,  #TempDiscretePickSlip.Size11                                           
         ,  #TempDiscretePickSlip.Qty11 
         ,  UserID = SUSER_NAME()                                                     
   FROM #TempDiscretePickSlip  
   JOIN #TMPORDER WITH (NOLOCK) ON (#TempDiscretePickSlip.Orderkey = #TMPORDER.Orderkey )                                                      
   JOIN ORDERS    WITH (NOLOCK) ON (#TempDiscretePickSlip.Orderkey = ORDERS.Orderkey)
   JOIN STORER    WITH (NOLOCK) ON (ORDERS.StorerKey= STORER.StorerKey) 
   JOIN FACILITY  WITH (NOLOCK) ON (ORDERS.Facility = FACILITY.Facility)
   ORDER BY ISNULL(RTRIM(ORDERS.ConsigneeKey),'')
         ,  ISNULL(RTRIM(ORDERS.C_Address1),'') 
         ,  ISNULL(RTRIM(ORDERS.UserDefine03),'')                                                  --(Wan01)
         ,  #TempDiscretePickSlip.Lottable01                                                       --(Wan01)
         ,  ORDERS.Orderkey                                                                        --(Wan01)
         ,  #TempDiscretePickSlip.SeqNo

   DROP TABLE #TempDiscretePickSlip
   --DROP TABLE #ORDERQTY
   --DROP TABLE #TempSize

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END

   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTCnt
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
      execute nsp_logerror @n_err, @c_errmsg, 'isp_GetDiscretePickTicketUSA_V5_1'
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