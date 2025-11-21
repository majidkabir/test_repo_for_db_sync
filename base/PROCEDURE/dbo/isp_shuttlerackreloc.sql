SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Proc : isp_shuttlerackreloc                                      */
/* Creation Date:                                                          */
/* Copyright: IDS                                                          */
/* Written by: CSCHONG                                                     */
/*                                                                         */
/* Purpose: SOS#358319:Project Merlion- Shuttle Rack Relocation Report     */
/*                                                                         */
/*                                                                         */
/* Usage:                                                                  */
/*                                                                         */
/* Local Variables:                                                        */
/*                                                                         */
/* Called By: r_dw_shuttlerackreloc                                        */
/*                                                                         */
/* PVCS Version: 1.1                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date        Author      Ver   Purposes                                  */
/* 05-07-2016  CSCHONG     1.0   fix commit execution error (CS01)         */
/* 22-07-2016  MTTEY       1.1   Insert condition Qty>0                    */
/*                               Ticket: FBR#358319  & IN00098349 (MT02)   */
/***************************************************************************/

CREATE PROC [dbo].[isp_shuttlerackreloc] (@c_facilitystart NVARCHAR(5)  ,
                                      @c_facilityend NVARCHAR(5) ,
                                      @c_storerkeystart NVARCHAR(15) ,
                                      @c_storerkeyend NVARCHAR(15) ,
                                      @c_sgetloc      NVARCHAR(20) ='',
                                      @c_DWCategory   NVARCHAR(1) = 'H')
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF


DECLARE  @c_pickheaderkey        NVARCHAR(10),
         @n_continue             INT,
         @c_errmsg               NVARCHAR(255),
         @b_success              INT,
         @n_err                  INT,
         @c_sku                  NVARCHAR(22),
         @n_qty                  INT,
         @c_loc                  NVARCHAR(10),
         @n_MaxPallet            INT,
         @n_CntPallet            INT,
         @n_TTLqty               INT,
         @c_sloc                 NVARCHAR(10),
         @c_sBatchno             NVARCHAR(18),
         @n_sMaxPallet           INT,
         @n_sttlpallet           INT,
         @n_scntpallet           INT,
         @n_sTTLqty              INT,
         @c_S_Group              INT,
         @c_S_PalletID           NVARCHAR(18)

DECLARE @n_starttcnt INT
SELECT  @n_starttcnt = @@TRANCOUNT

BEGIN TRAN --CS01

WHILE @@TRANCOUNT > 0
BEGIN
   COMMIT TRAN
END

CREATE TABLE #temp_shuttlerackreloc
         (loc           NVARCHAR(10) NULL,
          MaxPallet     INT,
          CntPallet     INT,
          SKU            NVARCHAR(20),
          AltSku         NVARCHAR(20) NULL,
          BatchNo        NVARCHAR(18),
          TTLQty            INT,
          [User]          NVARCHAR(15),
          [Show]          NVARCHAR(1) DEFAULT 'N' ,
          facstart   NVARCHAR(5),
          facend     NVARCHAR(5),
          storerstart  NVARCHAR(15),
          storerend    NVARCHAR(15)
      )

 CREATE TABLE #temp_shuttleRackID
 (loc           NVARCHAR(10) NULL,
  PalletID       NVARCHAR(18) NULL,
  Qty            INT)

   INSERT INTO #Temp_shuttlerackreloc
      (loc,   MaxPallet,     CntPallet,       SKU,
      AltSku,      BatchNo,  TTLQty,[user],facstart,
      facend,storerstart,storerend
   )

      SELECT DISTINCT lotxlocxid.loc,
                      Loc.Maxpallet,
                      0,
                      Lotxlocxid.Sku,
                      Sku.AltSku,
                      LOTATTRIBUTE.Lottable01,
                      0,
                      SUSER_SNAME() as [user],
                     @c_facilitystart ,
                     @c_facilityend,
                     @c_storerkeystart,
                     @c_storerkeyend
      FROM Lotxlocxid WITH (NOLOCK)
      JOIN LOC WITH (NOLOCK) ON LOC.LOC = Lotxlocxid.LOC
      JOIN SKU WITH (NOLOCK) ON SKU.SKU = Lotxlocxid.SKU
      JOIN LOTATTRIBUTE WITH (NOLOCK) ON LOTATTRIBUTE.Lot = Lotxlocxid.LOT
      WHERE Locationhandling = 'Shuttle'
      AND Loc.Facility BETWEEN @c_facilitystart and @c_facilityend
      AND Lotxlocxid.Storerkey between @c_storerkeystart and @c_storerkeyend
      AND (Lotxlocxid.Qty-Lotxlocxid.Qtypicked)>0
      AND Loc.Maxpallet > 0
      ORDER BY lotxlocxid.LOC


    DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR

   SELECT DISTINCT loc,Maxpallet from #Temp_shuttlerackreloc
   ORDER BY loc,MaxPallet

   OPEN CUR_RowNoLoop

   FETCH NEXT FROM CUR_RowNoLoop INTO @c_loc,@n_MaxPallet

   WHILE @@FETCH_STATUS <> -1
   BEGIN


   INSERT INTO #temp_shuttleRackID
   SELECT loc,id,qty
   FROM lotxlocxid WITH (NOLOCK)
   WHERE loc= @c_loc and qty>0                   -- (MT02)


  SET @n_TTLqty = 0
  SET @n_cntpallet = 0

  SELECT @n_TTLqty=SUM(qty),
         @n_cntpallet = COUNT(1)
  FROM  #temp_shuttleRackID
  WHERE loc = @c_loc

  UPDATE #Temp_shuttlerackreloc
  SET TTLqty = @n_TTLqty
     ,cntPallet = @n_cntpallet
  WHERE loc = @c_loc


  FETCH NEXT FROM  CUR_RowNoLoop INTO @c_loc,@n_MaxPallet
  END
  CLOSE CUR_RowNoLoop
  DEALLOCATE CUR_RowNoLoop

   IF @c_DWCategory = 'D'
   BEGIN
      GOTO Detail
   END

   HEADER:

   DECLARE CUR_ShuttleLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR

   SELECT DISTINCT loc,Maxpallet,cntpallet--,sku,altsku,batchno,ttlqty
   from #temp_shuttlerackreloc
   ORDER BY loc,MaxPallet

   OPEN CUR_ShuttleLoop

   FETCH NEXT FROM CUR_ShuttleLoop INTO @c_sloc,@n_sMaxPallet,@n_sttlpallet--,@c_sBatchno,@n_sTTLqty

   WHILE @@FETCH_STATUS <> -1
   BEGIN

    IF ((@n_sMaxPallet = 15 AND @n_sttlpallet <= 10)
     OR (@n_sMaxPallet = 10 AND @n_sttlpallet <= 5)
     OR (@n_sMaxPallet = 6 AND @n_sttlpallet <= 2))
   BEGIN

   UPDATE #Temp_shuttlerackreloc
   SET Show = 'Y'
   WHERE LOC = @c_sloc

   END

   FETCH NEXT FROM CUR_ShuttleLoop INTO @c_sloc,@n_sMaxPallet,@n_sttlpallet
   END

   CLOSE CUR_ShuttleLoop
   DEALLOCATE CUR_ShuttleLoop



   SELECT * FROM #Temp_shuttlerackreloc
   --WHERE Show ='Y'

   GOTO QUIT_SP

   DETAIL:

   SELECT PalletId FROM #temp_shuttleRackID
   WHERE Loc = @c_sgetloc

   GOTO QUIT_SP

   DROP TABLE #Temp_shuttlerackreloc
   DROP TABLE #temp_shuttleRackID

   QUIT_SP:
   END


GO