SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_GenerateBlankCC                                */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[nsp_GenerateBlankCC] (
@c_facility_start NVARCHAR(10),
@c_facility_end	  NVARCHAR(10),
@c_zone_start	  NVARCHAR(10),
@c_zone_end	  NVARCHAR(10),
@c_aisle_start	  NVARCHAR(10),
@c_aisle_end	  NVARCHAR(10),
@n_level_start	  int,
@n_level_end	  int
)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_loc NVARCHAR(10),
   @c_locaisle NVARCHAR(10),
   @c_Facility NVARCHAR(10),
   @n_LocLevel int,
   @c_prev_locaisle NVARCHAR(10),
   @n_Prev_LocLevel int,
   @c_Prev_Facility NVARCHAR(10),
   @c_detailkey NVARCHAR(10),
   @c_sheetno NVARCHAR(10),
   @n_count int,
   @b_success int,
   @n_err int,
   @c_errmsg NVARCHAR(250)
   DECLARE cur_1 CURSOR FAST_FORWARD READ_ONLY
   FOR
   SELECT Facility, LOC, locaisle, loclevel
   FROM  LOC (NOLOCK)
   WHERE (facility BETWEEN @c_facility_start AND @c_facility_end)
   AND (putawayzone BETWEEN @c_zone_start AND @c_zone_end)
   AND (locaisle BETWEEN @c_aisle_start AND @c_aisle_end)
   AND (loclevel BETWEEN @n_level_start AND @n_level_end)
   ORDER BY Facility, locaisle, loclevel, loc
   OPEN cur_1
   FETCH NEXT from cur_1 INTO @c_Facility, @c_loc, @c_locaisle, @n_LocLevel
   SELECT @c_prev_locaisle = '', @n_count = 0, @n_Prev_LocLevel = 0, @c_Prev_Facility = ''
   WHILE (@@fetch_status <> -1)
   BEGIN
      -- get ccdetailkey
      EXECUTE nspg_getkey
      "CCDetailKey"
      , 10
      , @c_detailkey OUTPUT
      , @b_success OUTPUT
      , @n_err OUTPUT
      , @c_errmsg OUTPUT
      -- check for page break by ccsheetno and aisle
      IF @n_count = 10 OR
      @c_prev_locaisle <> @c_locaisle OR
      @n_Prev_LocLevel <> @n_LocLevel OR
      @c_Prev_Facility <> @c_Facility
      BEGIN -- generate new ccsheetno
         -- get sheet no
         EXECUTE nspg_getkey
         "CCSheetNo"
         , 10
         , @c_sheetno OUTPUT
         , @b_success OUTPUT
         , @n_err OUTPUT
         , @c_errmsg OUTPUT
         -- insert ccdetail
         INSERT CCDETAIL (cckey, ccdetailkey, ccsheetno, loc) VALUES ('XXXXXXXXXX', @c_detailkey, @c_sheetno, @c_loc)
      IF @n_count = 0 SELECT @n_count = @n_count + 1 ELSE SELECT @n_count = 1
      END
   ELSE -- continue inserting into ccdetail
      BEGIN
         INSERT CCDETAIL (cckey, ccdetailkey, ccsheetno, loc) VALUES ('XXXXXXXXXX', @c_detailkey, @c_sheetno, @c_loc)
         SELECT @n_count = @n_count + 1
      END
      SELECT @c_prev_locaisle = @c_locaisle
      SELECT @c_Prev_Facility = @c_Facility
      SELECT @n_Prev_LocLevel = @n_LocLevel
      FETCH NEXT from cur_1 INTO @c_Facility, @c_loc, @c_locaisle, @n_LocLevel
   END
   CLOSE cur_1
   DEALLOCATE cur_1
END

GO