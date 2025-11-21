SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspOrderProcessingWave                             */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 12-Jul-2017  TLTING  1.1   missing (NOLOCK)                          */ 
/************************************************************************/


/*******************************************************************
* Modification History:
*
* 06/11/2002 Leo Ng  Program rewrite for IDS version 5
* *****************************************************************/

CREATE PROC [dbo].[nspOrderProcessingWave] (
@c_CartonBatch                NVARCHAR(10),
@c_OrderSelectionKey          NVARCHAR(10),
@b_Success    int   OUTPUT,
@n_err     int   OUTPUT,
@c_errmsg     NVARCHAR(250)  OUTPUT
) AS
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF	

   DECLARE @b_debug int
   SELECT @b_debug = 0
   IF @b_debug = 1
   BEGIN
      SELECT @c_CartonBatch "CartonBatch", @c_OrderSelectionKey "OrderSelectionKey"
   END
   DECLARE        @n_continue int        ,
   @n_starttcnt int        , -- Holds the current transaction count
   @c_preprocess NVARCHAR(250) , -- preprocess
   @c_pstprocess NVARCHAR(250) , -- post process
   @n_err2 int              -- For Additional Error Detection
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",@n_err2=0
   /* #INCLUDE <SPOPW1.SQL> */
   DECLARE
   @c_WaveOption            NVARCHAR(10),
   @n_BatchPickMaxCube      int,
   @n_BatchPickMaxCount     int
   SELECT
   @c_WaveOption         = WaveOption,
   @n_BatchPickMaxCube   = BatchPickMaxCube,
   @n_BatchPickMaxCount  = BatchPickMaxCount
   FROM ORDERSELECTION with (NOLOCK)
   WHERE     OrderSelectionKey = @c_OrderSelectionKey
   IF @@ROWCOUNT = 0
   BEGIN
      SELECT @n_continue = 3
      SELECT @n_err = 70600
      SELECT @c_errmsg = "NSQL" + CONVERT(char(5), @n_err) + ": Bad OrderSelectionKey. (nspOrderProcessingWave)"
   END
ELSE IF @b_debug = 1
   BEGIN
      SELECT @c_WaveOption "WaveOption", @n_BatchPickMaxCube "BatchPickMaxCube", @n_BatchPickMaxCount "BatchPickMaxCount"
   END
   IF @n_continue=1 or @n_continue=2
   BEGIN
      IF @c_WaveOption = "DISCRETE"
      BEGIN
         SELECT @b_success = 0
         EXECUTE nspOrderWaveDiscrete
         @c_CartonBatch,
         @b_success   OUTPUT,
         @n_err    OUTPUT,
         @c_errmsg    OUTPUT
         IF NOT @b_success = 1
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 70600
            SELECT @c_errmsg = "NSQL" + CONVERT(char(5),@n_err) + ": EXECUTE nspOrderWaveDiscrete failed (nspOrderProcessingWave)"
         END
      END
   ELSE IF @c_WaveOption = "ZONESEQ"
      BEGIN
         SELECT @b_success = 0
         EXECUTE nspOrderWaveDiscrete
         @c_CartonBatch,
         @b_success   OUTPUT,
         @n_err    OUTPUT,
         @c_errmsg    OUTPUT
         IF NOT @b_success = 1
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 70601
            SELECT @c_errmsg = "NSQL" + CONVERT(char(5),@n_err) + ": EXECUTE nspOrderWaveDiscrete failed (nspOrderProcessingWave)"
         END
      END
   ELSE IF @c_WaveOption = "ZONESIM"
      BEGIN
         SELECT @b_success = 0
         EXECUTE nspOrderWaveZoneSim
         @c_CartonBatch,
         @b_success   OUTPUT,
         @n_err    OUTPUT,
         @c_errmsg    OUTPUT
         IF NOT @b_success = 1
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 70602
            SELECT @c_errmsg = "NSQL" + CONVERT(char(5),@n_err) + ": EXECUTE nspOrderWaveZoneSim failed (nspOrderProcessingWave)"
         END
      END
   ELSE IF @c_WaveOption = "BATCH"
      BEGIN
         IF @n_BatchPickMaxCube > 0
         BEGIN
            SELECT @b_success = 0
            EXECUTE nspOrderWaveBatchCube
            @c_CartonBatch,
            @n_BatchPickMaxCube,
            @b_success   OUTPUT,
            @n_err    OUTPUT,
            @c_errmsg    OUTPUT
            IF NOT @b_success = 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 70603
               SELECT @c_errmsg = "NSQL" + CONVERT(char(5),@n_err) + ": EXECUTE nspOrderWaveBatchCube failed (nspOrderProcessingWave)"
            END
         END
      ELSE IF @n_BatchPickMaxCount > 0
         BEGIN
            SELECT @b_success = 0
            EXECUTE nspOrderWaveBatchQty
            @c_CartonBatch,
            @n_BatchPickMaxCount,
            @b_success   OUTPUT,
            @n_err    OUTPUT,
            @c_errmsg    OUTPUT
            IF NOT @b_success = 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 70604
               SELECT @c_errmsg = "NSQL" + CONVERT(char(5),@n_err) + ": EXECUTE nspOrderWaveBatchQty failed (nspOrderProcessingWave)"
            END
         END
      END
   ELSE IF @c_WaveOption = "BATCHZONE"
      BEGIN
         IF @n_BatchPickMaxCube > 0
         BEGIN
            SELECT @b_success = 0
            EXECUTE nspOrderWaveBatchZoneCube
            @c_CartonBatch,
            @n_BatchPickMaxCube,
            @b_success   OUTPUT,
            @n_err    OUTPUT,
            @c_errmsg    OUTPUT
            IF NOT @b_success = 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 70605
               SELECT @c_errmsg = "NSQL" + CONVERT(char(5),@n_err) + ": EXECUTE nspOrderWaveBatchZoneCube failed (nspOrderProcessingWave)"
            END
         END
      ELSE IF @n_BatchPickMaxCount > 0
         BEGIN
            SELECT @b_success = 0
            EXECUTE nspOrderWaveBatchZoneQty
            @c_CartonBatch,
            @n_BatchPickMaxCount,
            @b_success   OUTPUT,
            @n_err    OUTPUT,
            @c_errmsg    OUTPUT
            IF NOT @b_success = 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 70606
               SELECT @c_errmsg = "NSQL" + CONVERT(char(5),@n_err) + ": EXECUTE nspOrderWaveBatchZoneQty failed (nspOrderProcessingWave)"
            END
         END
      END
   END
   /* #INCLUDE <SPOPW2.SQL> */
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt
      BEGIN
         ROLLBACK TRAN
      END
   ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_starttcnt
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, "nspOrderProcessingWave"
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END



GO