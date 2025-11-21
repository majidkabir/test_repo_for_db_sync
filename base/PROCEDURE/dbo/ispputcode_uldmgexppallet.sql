SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispPutCode_ULDmgExpPallet                          */
/* Copyright: Maersk WMS                                               */
/*                                                                      */
/* Purpose: Filter Damage/Expired locations for damaged/expired pallet  */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2024-05-20   NLT013    1.0   FCR-186 Created                         */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispPutCode_ULDmgExpPallet]
    @n_PTraceHeadKey             NVARCHAR(10)
   ,@n_PTraceDetailKey           NVARCHAR(10)
   ,@c_PutawayStrategyKey        NVARCHAR(10)
   ,@c_PutawayStrategyLineNumber NVARCHAR(5)
   ,@c_StorerKey NVARCHAR(15)
   ,@c_SKU       NVARCHAR(20)
   ,@c_LOT       NVARCHAR(10)
   ,@c_FromLoc   NVARCHAR(10)
   ,@c_ID        NVARCHAR(18)
   ,@n_Qty       INT     
   ,@c_ToLoc     NVARCHAR(10)
   ,@c_Param1    NVARCHAR(20)
   ,@c_Param2    NVARCHAR(20)
   ,@c_Param3    NVARCHAR(20)
   ,@c_Param4    NVARCHAR(20)
   ,@c_Param5    NVARCHAR(20)
   ,@b_debug     INT
   ,@c_SQL       NVARCHAR( 1000) OUTPUT
   ,@b_RestrictionsPassed INT   OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE 
      @c_Reason            NVARCHAR(80),
   --FCR-186 Check if the pallet is damage or expired
      @cDamage             NVARCHAR(1)    = 'N',
      @cExpired            NVARCHAR(1)    = 'N',
      @cPALottable         NVARCHAR(30)   = '',
      @cExpiredLottable    NVARCHAR(10)   = 'LOTTABLE07',
      @cExpiredPriority    NVARCHAR(10)   = '2',
      @cExpiredRefCode     NVARCHAR(10)   = '',
      @cDamageLottable     NVARCHAR(10)   = 'LOTTABLE12',
      @cDamagePriority     NVARCHAR(10)   = '1',
      @nFunID              INT = 1819,
      @nExpiredPriority    INT = 99, 
      @nDamagePriority     INT = 99,
      @cDamageRoom         NVARCHAR( 30)  = 'DAMAGED',
      @cExpiredRoom        NVARCHAR( 30)  = 'EXPIRED'

	  --NICK
	  DECLARE @NICKMSG NVARCHAR(600)
	  SET @NICKMSG = CONCAT_WS(',' , 'ispPutCode_ULDmgExpPallet',@cExpired,   @cDamage, @c_SQL)
	  UPDATE RDT.RDTMOBREC SET V_Barcode = @NICKMSG WHERE UserName = 'NLT013'

   SET @cPALottable = rdt.RDTGetConfig( @nFunID, 'DiversePutawayLottables', @c_StorerKey)
   IF @cPALottable = '0'
      SET @cPALottable = ''

   IF @cPALottable IS NOT NULL AND @cPALottable <> ''
   BEGIN
      SELECT TOP 1 
         @cExpiredLottable    = Code,
         @cExpiredPriority    = ISNULL(UDF01, '99'),
         @cExpiredRefCode     = ISNULL(UDF02, '')
      FROM dbo.CODELKUP WITH (NOLOCK)
      WHERE LISTNAME = @cPALottable
         AND code2 = 'EXPIRED'
         AND (Storerkey = @c_StorerKey OR Storerkey = '')

      SELECT TOP 1 
         @cDamageLottable     = Code,
         @cDamagePriority     = ISNULL(UDF01, '99')
      FROM dbo.CODELKUP WITH (NOLOCK) 
      WHERE LISTNAME = @cPALottable
         AND code2 = 'DAMAGED'
         AND (Storerkey = @c_StorerKey OR Storerkey = '') 

      IF EXISTS (SELECT 1 FROM dbo.LOTxLOCxID inv WITH(NOLOCK)
               INNER JOIN dbo.LOTAttribute lot WITH(NOLOCK) ON inv.Lot = lot.Lot
               WHERE inv.ID          = @c_ID 
                  AND inv.Storerkey  = @c_StorerKey
                  AND lot.LOTTABLE12 IS NOT NULL AND lot.LOTTABLE12 <> '')
         SET @cDamage = 'Y'

      IF EXISTS (SELECT 1 FROM dbo.LOTxLOCxID inv WITH(NOLOCK)
               INNER JOIN dbo.LOTAttribute lot WITH(NOLOCK) ON inv.Lot = lot.Lot
               INNER JOIN (SELECT StorerKey, Code FROM dbo.CODELKUP WITH (NOLOCK)
                           WHERE StorerKey = @c_StorerKey
                              AND LISTNAME = @cExpiredRefCode) clk
                  ON inv.StorerKey = clk.StorerKey
                  AND ISNULL(lot.LOTTABLE07, '') = clk.Code
               WHERE inv.ID          = @c_ID 
                  AND inv.Storerkey  = @c_StorerKey)
         SET @cExpired = 'Y'
   END

   -- Generate T-SQL
   IF @c_ToLoc = ''
   BEGIN
      IF @b_debug = 1
         -- Putaway trace turn on, LOC is not pre-filter out
         SET @c_SQL = '' 
      ELSE
      BEGIN
         SET @nExpiredPriority = IIF( TRY_CAST(@cExpiredPriority AS INT) IS NULL OR TRY_CAST(@cExpiredPriority AS INT) < 1, 99, TRY_CAST(@cExpiredPriority AS INT) )
         SET @nDamagePriority = IIF( TRY_CAST(@cDamagePriority AS INT) IS NULL OR TRY_CAST(@cDamagePriority AS INT) < 1, 99, TRY_CAST(@cDamagePriority AS INT) )

         IF @cDamage = 'Y' AND @cExpired <> 'Y'
         BEGIN
            SET @c_SQL = 
               ' AND ISNULL(LOC.LocationRoom, '''') = ''' + @cDamageRoom + ''''
         END
         ELSE IF @cExpired = 'Y' AND @cDamage <> 'Y'
            SET @c_SQL = 
               ' AND ISNULL(LOC.LocationRoom, '''') = ''' + @cExpiredRoom + ''''
         ELSE IF @cExpired = 'Y' AND @cDamage = 'Y'
         BEGIN
            IF @cDamagePriority <= @cExpiredPriority
               SET @c_SQL = 
                  ' AND ISNULL(LOC.LocationRoom, '''') = ''' + @cDamageRoom + ''''
            ELSE
               SET @c_SQL = 
                  ' AND ISNULL(LOC.LocationRoom, '''') = ''' + @cExpiredRoom + ''''
         END
         ELSE IF @cExpired <> 'Y' AND @cDamage <> 'Y'
            SET @c_SQL = 
               ' AND ISNULL(LOC.LocationRoom, '''') NOT IN  (''' + @cDamageRoom + '''' + ',''' + @cExpiredRoom + ''')'
      END

	  --NICK
	  --DECLARE @NICKMSG NVARCHAR(600)
	  SET @NICKMSG = CONCAT_WS(',' , 'ispPutCode_ULDmgExpPallet',@cExpired,   @cDamage, @c_SQL)
	  UPDATE RDT.RDTMOBREC SET V_Barcode = @NICKMSG WHERE UserName = 'NLT013'
      RETURN
   END
   
   -- Restriction test
   IF @c_ToLoc <> ''
   BEGIN
      DECLARE @cLocRoom NVARCHAR(30)

      SELECT @cLocRoom = ISNULL(loc1.LocationRoom, '')
      FROM dbo.LOC AS loc WITH(NOLOCK)
      INNER JOIN dbo.LOC AS loc1 WITH(NOLOCK)
         ON loc.Facility= loc1.Facility
      WHERE 
         loc.Loc = @c_FromLoc
         AND loc1.Loc = @c_ToLoc

       IF @cDamage = 'Y' AND @cExpired <> 'Y' AND @cLocRoom <> @cDamageRoom
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED PutCode: ispPutCode_ULDmgExpPallet, Pallet is damaged, LocRoom = ' + @cLocRoom
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END
         SET @b_RestrictionsPassed = 0 --False
         RETURN
      END
      ELSE IF @cExpired = 'Y' AND @cDamage <> 'Y' AND @cLocRoom <> @cExpiredRoom
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED PutCode: ispPutCode_ULDmgExpPallet, Pallet is expired, LocRoom = ' + @cLocRoom
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END
         SET @b_RestrictionsPassed = 0 --False
         RETURN
      END
      ELSE IF @cExpired <> 'Y' AND @cDamage <> 'Y' AND ( @cLocRoom = @cDamageRoom OR @cLocRoom = @cExpiredRoom )
      BEGIN
         IF @b_debug = 1
         BEGIN
            SELECT @c_Reason = 'FAILED PutCode: ispPutCode_ULDmgExpPallet, Pallet is neither expired nor damaged, LocRoom = ' + @cLocRoom
            EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
         END
         SET @b_RestrictionsPassed = 0 --False
         RETURN
      END
      ELSE IF @cExpired = 'Y' AND @cDamage = 'Y'
      BEGIN
         IF @cDamagePriority <= @cExpiredPriority AND @cLocRoom <> @cDamageRoom
         BEGIN
            IF @b_debug = 1
            BEGIN
               SELECT @c_Reason = 'FAILED PutCode: ispPutCode_ULDmgExpPallet, Pallet is damaged and expired, LocRoom = ' + @cLocRoom
               EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
            END
            SET @b_RestrictionsPassed = 0 --False
            RETURN
         END
         ELSE IF @cDamagePriority > @cExpiredPriority AND @cLocRoom <> @cExpiredRoom
         BEGIN
            IF @b_debug = 1
            BEGIN
               SELECT @c_Reason = 'FAILED PutCode: ispPutCode_ULDmgExpPallet, Pallet is expired and expired, LocRoom = ' + @cLocRoom
               EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
            END
            SET @b_RestrictionsPassed = 0 --False
            RETURN
         END
      END

      IF @b_debug = 1
      BEGIN
         SELECT @c_Reason = 'PASSED PutCode: ispPutCode_ULDmgExpPallet, Damage Flag = ' + @cDamage + ', Expired flag = ' + @cExpired + ',  LocRoom = ' + @cLocRoom
         EXEC nspPTD 'nspRDTPASTD', @n_pTraceHeadKey, @c_PutawayStrategyKey, @c_PutawayStrategyLineNumber, @n_PtraceDetailKey, @c_ToLoc, @c_Reason
      END
      SET @b_RestrictionsPassed = 1 --False
   END
END

GO