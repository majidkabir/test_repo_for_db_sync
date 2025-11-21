SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_adjustment_detail                              */
/* Creation Date: 27-MAY-2009                                           */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose: Adjustment audit report able retrieve data from archive db  */
/*                                                                      */
/* Called By: Report module                                             */
/*                                                                      */
/* Parameters:                                                          */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 13/07/2009   audrey    1.1   SOS142122 - SQL 2005 compatible fix     */
/* 20/10/2014   SPChin    1.2   SOS323550 - Revise code lookup logic    */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_adjustment_detail]
 @c_adjustmentkey_start NVARCHAR(10),
 @c_adjustmentkey_end NVARCHAR(10),
 @c_storerkey_start NVARCHAR(15),
 @c_storerkey_end NVARCHAR(15),
 @dt_effectivedate_start datetime,
 @dt_effectivedate_end datetime,
 @c_facility_start NVARCHAR(5),
 @c_facility_end NVARCHAR(5)
AS
BEGIN
 SET NOCOUNT ON
  SET QUOTED_IDENTIFIER OFF
  SET ANSI_NULLS OFF
  SET CONCAT_NULL_YIELDS_NULL OFF

  DECLARE @c_arcdbname NVARCHAR(30),
          @sql nvarchar(4000)

  SELECT @c_arcdbname = ISNULL(NSQLValue,'') FROM NSQLCONFIG (NOLOCK)
  WHERE ConfigKey='ArchiveDBName'

  SELECT ADJUSTMENT.AdjustmentKey,
         ADJUSTMENT.StorerKey,
         ADJUSTMENT.EffectiveDate,
         ADJUSTMENTDETAIL.Sku,
         ADJUSTMENTDETAIL.Loc,
         ADJUSTMENTDETAIL.Id,
         ADJUSTMENTDETAIL.ReasonCode,
         ADJUSTMENTDETAIL.Qty,
         LOC.Facility,
         ISNULL(RTRIM(ADJUSTMENT.REMARKS),'') AS REMARKS,
         CODELKUP.DESCRIPTION
  INTO #TEMP_ADJ
  --SOS323550 Start
  --FROM ADJUSTMENT (NOLOCK),
  --     ADJUSTMENTDETAIL (NOLOCK),
  --   LOC (NOLOCK),
  --   CODELKUP (NOLOCK)
  FROM
  (SELECT DISTINCT CO.CODE, CO.DESCRIPTION FROM CODELKUP CO WITH (NOLOCK)
   JOIN ADJUSTMENTDETAIL ADJ WITH (NOLOCK)
   ON (ADJ.REASONCODE = CO.CODE AND CO.LISTNAME = 'ADJREASON')) AS CODELKUP
  JOIN ADJUSTMENTDETAIL ADJUSTMENTDETAIL WITH (NOLOCK) ON (ADJUSTMENTDETAIL.REASONCODE = CODELKUP.CODE)
  JOIN ADJUSTMENT ADJUSTMENT WITH (NOLOCK) ON (ADJUSTMENT.ADJUSTMENTKEY = ADJUSTMENTDETAIL.ADJUSTMENTKEY)
  JOIN LOC LOC WITH (NOLOCK) ON (ADJUSTMENTDETAIL.LOC = LOC.LOC)
  --SOS323550 End
  WHERE (ADJUSTMENT.AdjustmentKey = ADJUSTMENTDETAIL.AdjustmentKey ) and
     (ADJUSTMENTDETAIL.LOC = LOC.LOC) AND
        (ADJUSTMENT.AdjustmentKey >= @c_adjustmentkey_start) AND
        (ADJUSTMENT.AdjustmentKey <= @c_adjustmentkey_end) AND
        (ADJUSTMENT.StorerKey >= @c_storerkey_start) AND
        (ADJUSTMENT.StorerKey <= @c_storerkey_end) AND
        (ADJUSTMENT.EffectiveDate >=  @dt_effectivedate_start  ) AND
        (ADJUSTMENT.EffectiveDate < (select DateAdd(day,1, @dt_effectivedate_end ))) AND
     (LOC.Facility between @c_facility_start and @c_facility_end) --AND
     --(ADJUSTMENTDETAIL.REASONCODE = CODELKUP.CODE) AND	--SOS323550
     --(CODELKUP.LISTNAME = 'ADJREASON')						--SOS323550

  --IF (@c_arcdbname) <> ''  (SOS142122)
  IF ISNULL(RTRIM(@c_arcdbname),'') <> ''
  BEGIN
    SELECT @sql = 'INSERT INTO #TEMP_ADJ ' +
      + 'SELECT A.AdjustmentKey,    '
      + '         A.StorerKey,    '
      + '         A.EffectiveDate,    '
      + '         AD.Sku,    '
      + '         AD.Loc,    '
      + '         AD.Id,    '
      + '         AD.ReasonCode,    '
      + '         AD.Qty, '
      + '      L.Facility, '
      + '      ISNULL(RTRIM(A.REMARKS),'''') AS REMARKS, '
      + '      CL.DESCRIPTION       '
      --SOS323550 Start
      --+ '  FROM '+RTRIM(@c_arcdbname)+'..ADJUSTMENT A (NOLOCK),    '
      --+ RTRIM(@c_arcdbname)+'..ADJUSTMENTDETAIL AD (NOLOCK), '
      --+ ' LOC L (NOLOCK), '
      --+ ' CODELKUP CL (NOLOCK) '
      + ' FROM '
      + ' (SELECT DISTINCT CO.CODE, CO.DESCRIPTION FROM CODELKUP CO WITH (NOLOCK) '
      + ' 	JOIN '+RTRIM(@c_arcdbname)+'..ADJUSTMENTDETAIL ADJ WITH (NOLOCK) '
      + ' 	ON (ADJ.REASONCODE = CO.CODE AND CO.LISTNAME = ''ADJREASON'')) AS CL '
      + ' JOIN '+RTRIM(@c_arcdbname)+'..ADJUSTMENTDETAIL AD WITH (NOLOCK) ON (AD.REASONCODE = CL.CODE) '
      + ' JOIN '+RTRIM(@c_arcdbname)+'..ADJUSTMENT A WITH (NOLOCK) ON (A.ADJUSTMENTKEY = AD.ADJUSTMENTKEY) '
      + ' JOIN LOC L WITH (NOLOCK) ON (AD.LOC = L.LOC) '
      --SOS323550 End
      + '  WHERE (A.AdjustmentKey = AD.AdjustmentKey ) and   '
      + '      (AD.LOC = L.LOC) AND '
      + '        (A.AdjustmentKey >= N'''+ RTRIM(@c_adjustmentkey_start) +''') AND   '
      + '        (A.AdjustmentKey <= N'''+ RTRIM(@c_adjustmentkey_end) +''') AND   '
      + '        (A.StorerKey >= N'''+ RTRIM(@c_storerkey_start)+''') AND   '
      + '        (A.StorerKey <= N'''+ RTRIM(@c_storerkey_end) +''') AND   '
      + '        (A.EffectiveDate >= '''+ CONVERT(CHAR(8),@dt_effectivedate_start,112) +''') AND   '
      + '        (A.EffectiveDate < '''+ CONVERT(CHAR(8),(select DateAdd(day,1, @dt_effectivedate_end )),112) +''') AND '
      + '   (L.Facility between N'''+RTRIM(@c_facility_start)+''' AND N'''+ RTRIM(@c_facility_end)+''') ' --AND '
      --+ '   (AD.REASONCODE = CL.CODE) AND '--SOS323550
      --+ '   (CL.LISTNAME = ''ADJREASON'')'	--SOS323550

     EXEC(@sql)
   END

   SELECT * FROM #TEMP_ADJ ORDER BY storerkey, adjustmentkey, sku
END

GO