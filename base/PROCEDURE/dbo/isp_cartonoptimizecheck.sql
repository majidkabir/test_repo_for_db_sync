SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_CartonOptimizeCheck                                 */
/* Creation Date: 2020-09-04                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose:                                                             */
/*        :                                                             */
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
/* 09-OCT-2020 Wan      1.0   Created                                   */ 
/* 24-JUN-2021 Wan01    1.1   WMS-16805 - NIKE - PH Cartonization       */
/*                            Enhancement - Strategy fix                */
/*             Wan02          Standardize #OptimizeItemToPack Temp Table*/
/*                            Use at isp_SubmitToCartonizeAPI           */
/* 27-JUN-2021 Wan02    1.1   DevOps Combine Script                     */
/************************************************************************/
CREATE PROC [dbo].[isp_CartonOptimizeCheck]
           @c_CartonGroup  NVARCHAR(10)
         , @c_CartonType   NVARCHAR(10)   = ''     OUTPUT
         , @n_MaxCube      FLOAT          = 0.00   OUTPUT
         , @n_MaxWeight    FLOAT          = 0.00   OUTPUT
         , @n_QtyToPack    INT            = 0      OUTPUT
         , @b_CheckIfFix   INT            = 0               --Wan01 - CR1.8
         , @b_Success      INT            = 1      OUTPUT
         , @n_Err          INT            = 0      OUTPUT
         , @c_ErrMsg       NVARCHAR(255)  = ''     OUTPUT
         , @b_Debug        INT            = 0
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt          INT   = @@TRANCOUNT
         , @n_Continue           INT   = 1
                                 
         , @n_ID                 INT   = 0
         , @c_NewCartonType      NVARCHAR(10)   = ''  
         , @n_NewMaxCube         FLOAT          = 0.00
         , @n_NewMaxWeight       FLOAT          = 0.00
         , @c_OrigCartonType     NVARCHAR(10)   = ''  
         , @n_OrigMaxCube        FLOAT          = 0.00
         , @n_OrigMaxWeight      FLOAT          = 0.00

         , @n_Qty                INT            = 0
         , @n_PackQtyIndicator   INT            = 0
         , @n_QtyItemToReduce    INT            = 0
         , @c_Storerkey          NVARCHAR(15)   = ''
         , @c_Sku                NVARCHAR(20)   = ''

         , @c_IsCompletePack     NVARCHAR(10)   = ''  --2020-11-03
         
         , @n_Count              INT            = 0 

   IF OBJECT_ID('tempdb..#OptimizeItemToPack','U') IS NULL     --(Wan06)
   BEGIN
      CREATE TABLE #OptimizeItemToPack 
         (
            ID          INT                     IDENTITY(1,1)
         ,  Storerkey   NVARCHAR(15)   NOT NULL DEFAULT('') 
         ,  SKU         NVARCHAR(20)   NOT NULL DEFAULT('')
         ,  Dim1        DECIMAL(10,6)  NOT NULL DEFAULT(0.00)
         ,  Dim2        DECIMAL(10,6)  NOT NULL DEFAULT(0.00)
         ,  Dim3        DECIMAL(10,6)  NOT NULL DEFAULT(0.00)
         ,  Quantity    INT            NOT NULL DEFAULT(0)
         ,  RowRef      INT            NOT NULL DEFAULT(0)
         )
   END
   
   IF OBJECT_ID('tempdb..#t_ItemPack','U') IS NOT NULL      --Wan02
   BEGIN
      INSERT INTO #OptimizeItemToPack ( StorerKey, Sku, Dim1, Dim2, Dim3, Quantity, RowRef )
      SELECT StorerKey, Sku, Dim1, Dim2, Dim3, Quantity, ID
      FROM #t_ItemPack 
      ORDER BY ID
   END
      
   IF OBJECT_ID('tempdb..#OptimizeResult','U') IS NULL   
   BEGIN
       CREATE TABLE #OptimizeResult
       (    ContainerID       NVARCHAR(10)
       ,    AlgorithmID       NVARCHAR(10)
       ,    IsCompletePack    NVARCHAR(10) 
       ,    ID                INT
       ,    SKU               NVARCHAR(20)
       ,    Qty               INT 
       )
   END

   SET @c_OrigCartonType = @c_CartonType  --(Wan01)
   SET @n_OrigMaxCube    = @n_MaxCube     --(Wan01)
   SET @n_OrigMaxWeight  = @n_MaxWeight   --(Wan01)

   --SET @n_Qty = @n_QtyToPack            --(Wan01) CR1.8

   SET @n_ID = 0

   SELECT TOP 1 @n_ID = I.ID
      ,  @c_Storerkey = I.Storerkey
      ,  @c_Sku       = I.Sku
   FROM #OptimizeItemToPack I             --(Wan02)
   ORDER BY I.ID DESC

   SELECT @n_PackQtyIndicator = SKU.PackQtyIndicator
   FROM SKU WITH (NOLOCK)
   WHERE SKU.Storerkey = @c_Storerkey
   AND   SKU.Sku = @c_Sku

   --(Wan01) - START CR1.8
   IF @n_PackQtyIndicator > 1
   BEGIN
      SET @n_QtyToPack = FLOOR(@n_QtyToPack / @n_PackQtyIndicator)
   END
   
   SET @n_Qty = @n_QtyToPack 
   SET @n_QtyItemToReduce = 1
   --IF @n_PackQtyIndicator <= 1 
   --BEGIN
   --   SET @n_QtyItemToReduce = 1
   --END 
   --ELSE 
   --BEGIN
   --   IF @n_QtyToPack % @n_PackQtyIndicator > 0
   --   BEGIN
   --      SET @n_QtyItemToReduce = 1
   --   END
   --   ELSE
   --   BEGIN
   --      SET @n_QtyItemToReduce = @n_PackQtyIndicator
   --   END
   --END
   --(Wan01) - END CR1.8

   CARTONIZE_CHECK:
   IF @b_Debug = 1
   BEGIN 
      SELECT   @c_CartonType '@@c_CartonType- CARTONIZE_CHECK:'   
      PRINT @c_CartonGroup  + ': ' + @c_CartonType 
      PRINT '@n_QtyItemToReduce: ' + CAST(@n_QtyItemToReduce AS NVARCHAR)
         + ',@n_PackQtyIndicator:' + CAST(@n_PackQtyIndicator AS NVARCHAR)
   END

   TRUNCATE TABLE #OptimizeResult
   INSERT INTO #OptimizeResult (ContainerID, AlgorithmID, IsCompletePack, ID, SKU, Qty)
   EXEC isp_SubmitToCartonizeAPI
        @c_CartonGroup = @c_CartonGroup 
      , @c_CartonType  = @c_CartonType  
      , @b_Success     = @b_Success       OUTPUT
      , @n_Err         = @n_Err           OUTPUT
      , @c_ErrMsg      = @c_ErrMsg        OUTPUT
      --, @b_Debug       = @b_Debug

   IF @b_Success = 0
   BEGIN
      SET @n_Continue = 3
      SET @n_err = 84010  
      SET @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+': Error Executing isp_SubmitToCartonizeAPI. (isp_CartonOptimizeCheck)'   
                  + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '   
      GOTO QUIT_SP  
   END

   IF @b_Debug = 1
   BEGIN
      SELECT * FROM #OptimizeResult
      SELECT @n_Qty, @n_QtyToPack
   END

   --2020-11-03 - START
   SET @c_IsCompletePack = ''
   SELECT @c_IsCompletePack = IsCompletePack
   FROM #OptimizeResult

   IF @c_IsCompletePack = 'TRUE'
   BEGIN
      GOTO QUIT_SP
   END
   --2020-11-03 - END
   
   IF @n_Qty = @n_QtyToPack  -- Not Get bigger Carton yet
   BEGIN
      --Strategy 1) Get Bigger Carton
      SET @c_NewCartonType = ''
      SELECT TOP 1 @c_NewCartonType = CZ.CartonType
                  ,@n_NewMaxCube    = CZ.[Cube]
                  ,@n_NewMaxWeight  = CZ.MaxWeight
      FROM #NikeCTNGroup CZ WITH (NOLOCK)
      WHERE CZ.CartonizationGroup = @c_CartonGroup
      AND   CZ.[Cube]    >= @n_MaxCube
      AND   CZ.MaxWeight >= @n_MaxWeight
      AND   CZ.CartonType <> @c_CartonType
      ORDER BY CZ.[Cube] 
              ,CZ.MaxWeight

      IF @b_Debug = 1
      BEGIN
        SELECT @c_NewCartonType '@c_NewCartonType'  , @n_NewMaxCube '@n_NewMaxCube' 
                  ,@n_NewMaxWeight'@n_NewMaxWeight'   , @n_QtyToPack '@n_QtyToPack'
                  ,@n_MaxCube '@n_MaxCube', @n_MaxWeight '@n_MaxWeight', @c_CartonType '@c_CartonType'
        PRINT '@c_NewCartonType:' +@c_NewCartonType 
            + ', @n_NewMaxCube:' +  CAST(@n_NewMaxCube AS NVARCHAR)
            + ', @n_NewMaxWeight:' +  CAST(@n_NewMaxWeight AS NVARCHAR)
            + ', @n_QtyToPack:' +  CAST(@n_QtyToPack AS NVARCHAR)
      END 

      IF ISNULL(@c_NewCartonType,'') <> ''  -- If get bigger Carton, then check if can fit
      BEGIN        
         SET @c_CartonType= @c_NewCartonType
         SET @n_MaxCube   = @n_NewMaxCube
         SET @n_MaxWeight = @n_NewMaxWeight
         GOTO CARTONIZE_CHECK
      END
   END 

   --CR1.8 - START
   IF @b_CheckIfFix = 1
   BEGIN
      SET @n_QtyToPack = 0 
      GOTO QUIT_SP
   END
   --CR1.8 - END

   --Strategy 2) Reduce Pack Qty  
   SET @n_QtyToPack = @n_QtyToPack - @n_QtyItemToReduce
   
   IF @c_CartonType <> @c_OrigCartonType     --(Wan01)  Reduce 1 and try original Cartontype
   BEGIN
      SET @c_CartonType = @c_OrigCartonType 
      SET @n_MaxCube    = @n_OrigMaxCube
      SET @n_MaxWeight  = @n_OrigMaxWeight
      SET @n_Qty = @n_QtyToPack
   END                                       --(Wan01)

   IF @b_Debug = 1
   BEGIN
      PRINT 'N_QtyPack (B4 reduce): ' + CAST (@n_QtyToPack + @n_QtyItemToReduce AS NVARCHAR)
          + ',@n_QtyItemToReduce: ' + CAST (@n_QtyItemToReduce AS NVARCHAR)
          + ',@n_QtyToPack - @n_QtyItemToReduce:' +  cast(@n_QtyToPack as nvarchar)
   END

   IF @n_QtyToPack <= 0 
   BEGIN
      SELECT @n_Count = COUNT(1) FROM #OptimizeItemToPack  (NOLOCK)  --(Wan02) 
      IF (@n_Count > 1)  
      BEGIN  
         SET @n_QtyToPack = 0
         SET @c_CartonType= ''   --(Wan01) @c_OrigCartonType      -- to avoid confusion. No value assign anywhere on previous version hence @c_OrigCartonType =''
         SET @n_MaxCube   = 0.00 --(Wan01) @n_OrigMaxCube         -- to avoid confusion. No value assign anywhere on previous version hence @n_OrigMaxCube = 0.00
         SET @n_MaxWeight = 0.00 --(Wan01) @n_OrigMaxWeight       -- to avoid confusion. No value assign anywhere on previous version hence @n_OrigMaxWeight = 0.00

      END
      GOTO QUIT_SP
   END

   --SET @n_ID = 0
   --SELECT TOP 1 @n_ID = I.ID
   --FROM #t_ItemPack I
   --ORDER BY I.ID DESC

   UPDATE #OptimizeItemToPack             --(Wan02) 
      SET Quantity = @n_QtyToPack
   WHERE ID = @n_ID

   --(Wan01) - START CR1.8
   --IF @n_PackQtyIndicator > 1 AND @n_QtyToPack % @n_PackQtyIndicator = 0
   --BEGIN
   --   SET @n_QtyItemToReduce = @n_PackQtyIndicator
   --END
   --(Wan01) - END CR1.8

   GOTO CARTONIZE_CHECK

   QUIT_SP:

   SET @n_QtyToPack = @n_QtyToPack * @n_PackQtyIndicator --(Wan01) CR1.8
   
   --(Wan02) - START
   IF OBJECT_ID('tempdb..#t_ItemPack','U') IS NOT NULL      --Wan02
   BEGIN
      UPDATE t 
      SET Quantity = oitp.Quantity
      FROM #OptimizeItemToPack AS oitp
      JOIN #t_ItemPack t ON t.id= RowRef
   END
   --(Wan02) - END
   
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_CartonOptimizeCheck'
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