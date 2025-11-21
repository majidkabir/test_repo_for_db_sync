SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: ispCCStrategy01                                             */
/* Creation Date: 28-JUN-2016                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: SOS#370874 - TW Add Cycle Count Strategy                    */
/*        :                                                             */
/* Called By: ispCCStrategy                                             */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[ispCCStrategy01] 
            @c_StockTakeKey   NVARCHAR(10)
         ,  @b_Success        INT = 0  OUTPUT 
         ,  @n_err            INT = 0  OUTPUT 
         ,  @c_errmsg         NVARCHAR(255) = '' OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt             INT
         , @n_Continue              INT 
                                    
         , @n_Cnt                   INT
         , @c_Cnt                   CHAR(1)
         , @c_CCStrategykey         NVARCHAR(30)
         , @c_SPName                NVARCHAR(255)
         , @c_ParmField             NVARCHAR(30)
         , @c_ParmField01           NVARCHAR(30)
         , @c_ParmField02           NVARCHAR(30)
                                    
         , @c_SQL                   NVARCHAR(4000)
                                    
         , @c_ParmsSQL              NVARCHAR(4000)
         , @c_ParmsSQL1             NVARCHAR(4000)
         , @c_ParmsSQL2             NVARCHAR(4000)
                                    
         , @c_Parameter01           NVARCHAR(125)
         , @c_Parameter02           NVARCHAR(125)
                                    
         , @c_Facility              NVARCHAR(5)
         , @c_Storerkey             NVARCHAR(125)
         , @c_AisleParm             NVARCHAR(125) 
         , @c_LevelParm             NVARCHAR(125) 
         , @c_ZoneParm              NVARCHAR(125) 
         , @c_HostWHCodeParm        NVARCHAR(125) 
         , @c_SKUParm               NVARCHAR(125) 
         , @c_SKUGroupParm          NVARCHAR(125) 
         , @c_AgencyParm            NVARCHAR(125) 
         , @c_ABCParm               NVARCHAR(125) 

         , @c_EmptyLocation         NVARCHAR(1)
         , @c_ExcludeQtyPicked      NVARCHAR(1)
         , @c_ExcludeQtyAllocated   NVARCHAR(1)
         , @c_ExtendedParm          NVARCHAR(125) 
         , @c_ExtendedParm1         NVARCHAR(125) 
         , @c_ExtendedParm2         NVARCHAR(125) 
         , @c_ExtendedParm3         NVARCHAR(125) 
         , @c_ExtendedParmField     NVARCHAR(30) 
         , @c_ExtendedParm1Field    NVARCHAR(30) 
         , @c_ExtendedParm2Field    NVARCHAR(30) 
         , @c_ExtendedParm3Field    NVARCHAR(30)

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   BEGIN TRAN

   SET @c_CCStrategykey = ''
   SET @c_Storerkey = ''
   SET @c_ZoneParm = ''
   SET @c_AisleParm = ''
   SET @c_LevelParm = ''
   SET @c_HostWHCodeParm = ''
   SET @c_EmptyLocation = 'N'
   SET @c_ExcludeQtyPicked = 'N'
   SET @c_ExcludeQtyAllocated = 'N'

   SELECT @c_Facility           = Facility
         ,@c_Storerkey          = Storerkey
         ,@c_ZoneParm           = ISNULL(RTRIM(ZoneParm),'')
         ,@c_AisleParm          = ISNULL(RTRIM(AisleParm),'')
         ,@c_LevelParm          = ISNULL(RTRIM(LevelParm),'')
         ,@c_HostWHCodeParm     = ISNULL(RTRIM(HostWHCodeParm),'')
         ,@c_SkuParm            = ISNULL(RTRIM(SkuParm),'')
         ,@c_AgencyParm         = ISNULL(RTRIM(AgencyParm),'')
         ,@c_ABCParm            = ISNULL(RTRIM(ABCParm),'')
         ,@c_SkuGroupParm       = ISNULL(RTRIM(SkuGroupParm),'')
         ,@c_EmptyLocation      = ISNULL(RTRIM(EmptyLocation),'N')
         ,@c_ExcludeQtyPicked   = ISNULL(RTRIM(ExcludeQtyPicked),'N')
         ,@c_ExcludeQtyAllocated= ISNULL(RTRIM(ExcludeQtyAllocated ),'N')
         ,@c_ExtendedParm1Field = ISNULL(RTRIM(ExtendedParm1Field),'')
         ,@c_ExtendedParm1      = ISNULL(RTRIM(ExtendedParm1),'') 
         ,@c_ExtendedParm2Field = ISNULL(RTRIM(ExtendedParm2Field),'')
         ,@c_ExtendedParm2      = ISNULL(RTRIM(ExtendedParm2),'') 
         ,@c_ExtendedParm3Field = ISNULL(RTRIM(ExtendedParm3Field),'') 
         ,@c_ExtendedParm3      = ISNULL(RTRIM(ExtendedParm3),'')
         ,@c_CCStrategykey      = ISNULL(RTRIM(StrategyKey),'')
         ,@c_Parameter01        = ISNULL(RTRIM(Parameter01),'')
         ,@c_Parameter02        = ISNULL(RTRIM(Parameter02),'')
   FROM STOCKTAKESHEETPARAMETERS WITH (NOLOCK)
   WHERE StockTakeKey = @c_StockTakeKey

   SET @n_Cnt    = 0
   SET @c_ParmField01  = ''
   SET @c_ParmField02  = ''
   
   SELECT @n_Cnt    = 1
         ,@c_ParmField01  = ISNULL(RTRIM(UDF01),'')
         ,@c_ParmField02  = ISNULL(RTRIM(UDF02),'')
   FROM   CODELKUP WITH (NOLOCK)
   WHERE  ListName = 'CCSTRATEGY'
   AND    Code = @c_CCStrategykey
   ORDER BY Code
   
   IF @n_Cnt = 0 
   BEGIN
      GOTO QUIT_SP
   END

   CREATE TABLE #RESULT 
      (  Storerkey      NVARCHAR(15)   NULL
      ,  Sku            NVARCHAR(20)   NULL
      ,  Loc            NVARCHAR(10)   NULL
      ,  CycleCounter   INT            NULL
      )


   SET @c_ParmsSQL1 = ''
   SET @c_ParmsSQL2 = ''
   EXEC ispParseParameters 
         @c_Storerkey 
      ,  'string' 
      ,  'SKUxLOC.Storerkey' 
      ,  @c_ParmsSQL1   OUTPUT 
      ,  @c_ParmsSQL2   OUTPUT 
      ,  @b_Success     OUTPUT

   IF @c_ParmsSQL1 <> ''
   BEGIN
      SET @c_ParmsSQL = @c_ParmsSQL + STUFF(@c_ParmsSQL1, 6, 0,'(')  + ' OR SKUxLOC.Storerkey IS NULL) '  
   END

   IF @c_ParmsSQL2 <> ''
   BEGIN
      SET @c_ParmsSQL = @c_ParmsSQL + STUFF(@c_ParmsSQL2, 6, 0,'(')  + ' OR SKUxLOC.Storerkey IS NULL) ' 
   END

   SET @c_ParmsSQL1 = ''
   SET @c_ParmsSQL2 = ''
   EXEC ispParseParameters
         @c_ZoneParm
      ,  'string'
      ,  'LOC.PutawayZone'
      ,  @c_ParmsSQL1   OUTPUT 
      ,  @c_ParmsSQL2   OUTPUT 
      ,  @b_Success     OUTPUT

   SET @c_ParmsSQL = @c_ParmsSQL + ' ' + @c_ParmsSQL1 + ' ' + @c_ParmsSQL2

   SET @c_ParmsSQL1 = ''
   SET @c_ParmsSQL2 = ''
   EXEC ispParseParameters
         @c_AisleParm
      ,  'string'
      ,  'LOC.LocAisle'
      ,  @c_ParmsSQL1   OUTPUT 
      ,  @c_ParmsSQL2   OUTPUT 
      ,  @b_Success     OUTPUT

   SET @c_ParmsSQL = @c_ParmsSQL + ' ' + @c_ParmsSQL1 + ' ' + @c_ParmsSQL2

   SET @c_ParmsSQL1 = ''
   SET @c_ParmsSQL2 = ''
   EXEC ispParseParameters
         @c_LevelParm
      ,  'string'
      ,  'LOC.LocLevel'
      ,  @c_ParmsSQL1   OUTPUT 
      ,  @c_ParmsSQL2   OUTPUT 
      ,  @b_Success     OUTPUT

   SET @c_ParmsSQL = @c_ParmsSQL + ' ' + @c_ParmsSQL1 + ' ' + @c_ParmsSQL2

   SET @c_ParmsSQL1 = ''
   SET @c_ParmsSQL2 = ''
   EXEC ispParseParameters
         @c_HostWHCodeParm
      ,  'string'
      ,  'LOC.HostWHCode'
      ,  @c_ParmsSQL1   OUTPUT 
      ,  @c_ParmsSQL2   OUTPUT 
      ,  @b_Success     OUTPUT

   SET @c_ParmsSQL = @c_ParmsSQL + ' ' + @c_ParmsSQL1 + ' ' + @c_ParmsSQL2

   SET @c_ParmsSQL1 = ''
   SET @c_ParmsSQL2 = ''
   EXEC ispParseParameters 
         @c_AgencyParm 
      ,  'string' 
      ,  'SKU.Sku' 
      ,  @c_ParmsSQL1   OUTPUT 
      ,  @c_ParmsSQL2   OUTPUT 
      ,  @b_Success     OUTPUT

   IF @c_ParmsSQL1 <> ''
   BEGIN
      SET @c_ParmsSQL = @c_ParmsSQL + STUFF(@c_ParmsSQL1, 6, 0,'(')  + ' OR SKU.Sku IS NULL) '  
   END

   IF @c_ParmsSQL2 <> ''
   BEGIN
      SET @c_ParmsSQL = @c_ParmsSQL + STUFF(@c_ParmsSQL2, 6, 0,'(')  + ' OR SKU.Sku IS NULL) ' 
   END

   SET @c_ParmsSQL1 = ''
   SET @c_ParmsSQL2 = ''
   EXEC ispParseParameters 
         @c_AgencyParm 
      ,  'string' 
      ,  'SKU.SUSR3' 
      ,  @c_ParmsSQL1   OUTPUT 
      ,  @c_ParmsSQL2   OUTPUT 
      ,  @b_Success     OUTPUT

   IF @c_ParmsSQL1 <> ''
   BEGIN
      SET @c_ParmsSQL = @c_ParmsSQL + STUFF(@c_ParmsSQL1, 6, 0,'(')  + ' OR SKU.Sku IS NULL) '  
   END

   IF @c_ParmsSQL2 <> ''
   BEGIN
      SET @c_ParmsSQL = @c_ParmsSQL + STUFF(@c_ParmsSQL2, 6, 0,'(')  + ' OR SKU.Sku IS NULL) ' 
   END

   SET @c_ParmsSQL1 = ''
   SET @c_ParmsSQL2 = ''
   EXEC ispParseParameters 
        @c_ABCParm 
      , 'string'
      , 'SKU.ABC'       
      ,  @c_ParmsSQL1   OUTPUT 
      ,  @c_ParmsSQL2   OUTPUT 
      ,  @b_Success     OUTPUT

   IF @c_ParmsSQL1 <> ''
   BEGIN
      SET @c_ParmsSQL = @c_ParmsSQL + STUFF(@c_ParmsSQL1, 6, 0,'(')  + ' OR SKU.Sku IS NULL) '  
   END

   IF @c_ParmsSQL2 <> ''
   BEGIN
      SET @c_ParmsSQL = @c_ParmsSQL + STUFF(@c_ParmsSQL2, 6, 0,'(')  + ' OR SKU.Sku IS NULL) ' 
   END
 
   SET @c_ParmsSQL1 = ''
   SET @c_ParmsSQL2 = ''
   EXEC ispParseParameters 
        @c_SkuGroupParm 
      ,  'string' 
      ,  'SKU.SKUGROUP' 
      ,  @c_ParmsSQL1   OUTPUT 
      ,  @c_ParmsSQL2   OUTPUT 
      ,  @b_Success     OUTPUT

   IF @c_ParmsSQL1 <> ''
   BEGIN
      SET @c_ParmsSQL = @c_ParmsSQL + STUFF(@c_ParmsSQL1, 6, 0,'(') + ' OR SKU.Sku IS NULL) '  
   END

   IF @c_ParmsSQL2 <> ''
   BEGIN
      SET @c_ParmsSQL = @c_ParmsSQL + STUFF(@c_ParmsSQL2, 6, 0,'(')  + ' OR SKU.Sku IS NULL) ' 
   END

   SET @c_ParmsSQL1 = ''
   SET @c_ParmsSQL2 = ''
   EXEC ispParseParameters
         @c_Parameter02
      ,  'string'
      ,  @c_ParmField02
      ,  @c_ParmsSQL1   OUTPUT 
      ,  @c_ParmsSQL2   OUTPUT 
      ,  @b_Success     OUTPUT

   SET @c_ParmsSQL = @c_ParmsSQL + ' ' + @c_ParmsSQL1 + ' ' + @c_ParmsSQL2

   SET @n_Cnt = 1
   WHILE @n_Cnt <= 3
   BEGIN
      SET @c_Cnt = RTRIM(CONVERT(NVARCHAR(1), @n_Cnt))

      SET @c_SQL = N'SET @c_ExtendedParm = @c_ExtendedParm' + @c_Cnt
                 + ' SET @c_ExtendedParmField = @c_ExtendedParm' + @c_Cnt + 'Field'
         
      EXEC sp_ExecuteSql @c_SQL         
              , N' @c_ExtendedParm       NVARCHAR(125) OUTPUT
                 , @c_ExtendedParmField  NVARCHAR(30)  OUTPUT
                 , @c_ExtendedParm1      NVARCHAR(125)
                 , @c_ExtendedParm2      NVARCHAR(125)
                 , @c_ExtendedParm3      NVARCHAR(125)
                 , @c_ExtendedParm1Field NVARCHAR(30)
                 , @c_ExtendedParm2Field NVARCHAR(30)
                 , @c_ExtendedParm3Field NVARCHAR(30)
                 '
              , @c_ExtendedParm       OUTPUT
              , @c_ExtendedParmField  OUTPUT           
              , @c_ExtendedParm1  
              , @c_ExtendedParm2
              , @c_ExtendedParm3
              , @c_ExtendedParm1Field 
              , @c_ExtendedParm2Field 
              , @c_ExtendedParm3Field

      SET @n_err = @@ERROR
      IF @n_err <> 0 
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 65010
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_err) + ': Error Executing SQL. (ispCCStrategy01)'
         GOTO QUIT_SP
      END

      IF RTRIM(@c_ExtendedParm) <> '' AND CHARINDEX('LOC.', @c_ExtendedParmField, 1) > 0
      BEGIN 
         SET @c_ParmsSQL1 = ''
         SET @c_ParmsSQL2 = ''
         EXEC ispParseParameters
               @c_ExtendedParm
            ,  'string'
            ,  @c_ExtendedParmField
            ,  @c_ParmsSQL1   OUTPUT 
            ,  @c_ParmsSQL2   OUTPUT 
            ,  @b_Success     OUTPUT

         SET @n_err = @@ERROR
         IF @n_err <> 0 
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 65020
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_err) + ': Error Executing SQL. (ispCCStrategy01)'
            GOTO QUIT_SP
         END

         SET @c_ParmsSQL = @c_ParmsSQL + ' ' + @c_ParmsSQL1 + ' ' + @c_ParmsSQL2
      END 
      SET @n_Cnt = @n_Cnt + 1
   END

   SET @c_SQL = N'SELECT DISTINCT TOP ' + @c_Parameter01 
              + ' ''''' -- Storerkey
              + ',''''' -- Sku
              + ',LOC.LOC'  -- Loc
              + ',LOC.CycleCounter'
              + ' FROM LOC WITH (NOLOCK)'
              + ' LEFT JOIN SKUxLOC WITH (NOLOCK) ON (SKUxLOC.Loc = LOC.Loc)'
              + ' LEFT JOIN SKU WITH (NOLOCK) ON (SKUxLOC.Storerkey = SKU.Storerkey)'
              +                            ' AND (SKUxLOC.Sku = SKU.Sku)'
              + ' WHERE LOC.Facility = N''' + RTRIM(@c_Facility) + ''''
              --+ ' AND (SKUxLOC.Storerkey IS NULL OR SKUxLOC.Storerkey = N''' + RTRIM(@c_Storerkey) + ''')'
              + ' ' + @c_ParmsSQL  
              + CASE WHEN @c_EmptyLocation = 'N' THEN ' AND SKUxLOC.Loc IS NOT NULL' ELSE ' ' END
              + CASE WHEN @c_ExcludeQtyAllocated = 'Y' AND @c_ExcludeQtyPicked = 'Y' THEN ' AND ISNULL(SKUxLOC.Qty,0)-ISNULL(SKUxLOC.Qtyallocated,0)-ISNULL(SKUxLOC.Qtypicked,0)'
                     WHEN @c_ExcludeQtyAllocated = 'Y' THEN ' AND ISNULL(SKUxLOC.Qty,0)-ISNULL(SKUxLOC.Qtyallocated,0)' 
                     WHEN @c_ExcludeQtyPicked    = 'Y' THEN ' AND ISNULL(SKUxLOC.Qty,0)-ISNULL(SKUxLOC.Qtypicked,0)'
                     ELSE ' AND ISNULL(SKUxLOC.Qty,0)' END
              + CASE WHEN @c_EmptyLocation = 'N' THEN ' > 0' ELSE ' >= 0' END
              + ' AND ISNULL(SKUxLOC.Qtyallocated,0)+ISNULL(SKUxLOC.Qtypicked,0) = 0'
              + ' ORDER BY LOC.CycleCounter, LOC.LOC'

   INSERT INTO #RESULT (Storerkey, Sku, Loc,CycleCounter)
   EXEC (@c_SQL)

   SET @n_err = @@ERROR
   IF @n_err <> 0 
   BEGIN
      SET @n_Continue = 3
      SET @n_err = 66030
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_err) + ': Error Executing SQL. (ispCCStrategy01)'
      GOTO QUIT_SP
   END

   IF EXISTS ( SELECT 1
               FROM #RESULT
            )
   BEGIN
      INSERT INTO STOCKTAKEPARMSTRATEGY
         (  StockTakeKey
         ,  Storerkey
         ,  Sku
         ,  Loc
         )
      SELECT @c_Stocktakekey
         ,  Storerkey
         ,  Sku
         ,  Loc
      FROM #RESULT
   END
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispCCStrategy01'
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