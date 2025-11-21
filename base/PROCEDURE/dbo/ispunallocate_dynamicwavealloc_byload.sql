SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispUnallocate_DynamicWaveAlloc_byLoad              */
/* Creation Date: 11-Aug-2008                                           */
/* Copyright: IDS                                                       */
/* Written by: MaryVong                                                 */
/*                                                                      */
/* Purpose: CN NIKE Bridge - Unallocate Dynamic Wave Allocation by Load */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By: Brio Report                                               */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author      Purposes                                    */
/* 2008-12-3    wwang       add Storerkey as parameter                  */
/************************************************************************/

CREATE PROC  [dbo].[ispUnallocate_DynamicWaveAlloc_byLoad]
   @c_Storerkey NVARCHAR(15),
   @c_WaveKey  NVARCHAR(10),
   @c_LoadKey  NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
      @n_continue  int,  /* continuation flag
                           1=Continue
                           2=failed but continue processsing
                           3=failed do not continue processing
                           4=successful but skip furthur processing */
      @n_starttcnt int, -- Holds the current transaction count
      @b_success   int,
      @n_err       int,
      @c_errmsg    NVARCHAR(250),
      @b_debug     int

   DECLARE
      @cReplenStarted NVARCHAR(1),
      @c_PickSlipNo NVARCHAR(10),
      @cReplenDone  NVARCHAR(1)
   
   SET @cReplenStarted='N'

   SET @cReplenDone = 'N'

   SELECT @n_starttcnt=@@TRANCOUNT, @n_continue=1, @b_success=0, @n_err=0, @c_errmsg='', @b_debug=0

   BEGIN TRAN

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      -- If NULL set WaveKey to blank
      IF ISNULL(RTRIM(@c_WaveKey),'') = ''
         SET @c_WaveKey = ''

      -- If NULL set LoadKey to blank
      IF ISNULL(RTRIM(@c_LoadKey),'') = ''
         SET @c_LoadKey = ''

      -- Check if blank WaveKey
      IF @c_WaveKey = ''
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 63001
         SELECT @c_errmsg = 'Empty WaveKey (ispUnallocate_DynamicWaveAlloc_byLoad)'
         GOTO RETURN_SP
      END

      -- Check if blank LoadKey
      IF @c_LoadKey = ''
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 63002
         SELECT @c_errmsg = 'Empty LoadKey (ispUnallocate_DynamicWaveAlloc_byLoad)'
         GOTO RETURN_SP
      END

      -- Check if WaveKey exists
      IF NOT EXISTS (SELECT 1 FROM WAVE WITH (NOLOCK)
                     WHERE WaveKey = @c_WaveKey )
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 63003
         SELECT @c_errmsg = 'WaveKey Not Found (ispUnallocate_DynamicWaveAlloc_byLoad)'
         GOTO RETURN_SP
      END

      -- Check if WaveDetail exists
      IF NOT EXISTS (SELECT 1 FROM WAVEDETAIL WITH (NOLOCK)
                     WHERE WaveKey = @c_WaveKey )
      BEGIN
         SELECT @n_continue = 3
   SELECT @n_err = 63004
         SELECT @c_errmsg = 'WaveDetail Not Found (ispUnallocate_DynamicWaveAlloc_byLoad)'
         GOTO RETURN_SP
      END

      -- Check if WaveKey closed
      IF EXISTS (SELECT 1 FROM WAVE WITH (NOLOCK)
                  WHERE WaveKey = @c_WaveKey
                  AND   Status = '9' )
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 63005
         SELECT @c_errmsg = 'WaveKey Closed (ispUnallocate_DynamicWaveAlloc_byLoad)'
         GOTO RETURN_SP
      END

      -- Check if LoadKey exists in Wave
      IF NOT EXISTS (SELECT 1 FROM ORDERS OH WITH (NOLOCK)
                     INNER JOIN LOADPLAN LP WITH (NOLOCK) ON (OH.LoadKey = LP.LoadKey)
                     WHERE OH.UserDefine09 = @c_WaveKey
                     AND   OH.Storerkey = @c_Storerkey
                     AND   OH.LoadKey = @c_LoadKey )
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 63006
         SELECT @c_errmsg = 'LoadKey Not Found in Wave (ispUnallocate_DynamicWaveAlloc_byLoad)'
         GOTO RETURN_SP
      END

      -- Any allocation
      IF NOT EXISTS (SELECT 1 FROM ORDERS OH WITH (NOLOCK)
                     INNER JOIN PICKDETAIL PD WITH (NOLOCK) ON (OH.OrderKey = PD.OrderKey AND PD.Storerkey = @c_Storerkey)
                     WHERE OH.UserDefine09 = @c_WaveKey
                     AND   OH.Storerkey = @c_Storerkey
                     AND   OH.LoadKey = @c_LoadKey
                     AND   PD.Status  < '5' )
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 63007
         SELECT @c_errmsg = 'No Order to Unallocate (ispUnallocate_DynamicWaveAlloc_byLoad)'
         GOTO RETURN_SP
      END

      -- Any Processed Order
      IF EXISTS (SELECT 1 FROM ORDERS OH WITH (NOLOCK)
                     INNER JOIN PICKDETAIL PD WITH (NOLOCK) ON (OH.OrderKey = PD.OrderKey AND PD.Storerkey = @c_Storerkey)
                     WHERE OH.UserDefine09 = @c_WaveKey
                     AND   OH.Storerkey = @c_Storerkey
                     AND   OH.LoadKey = @c_LoadKey
                     AND   PD.Status >= '5' )
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 63008
         SELECT @c_errmsg = 'Not Allowed to Unallocate Processed Order (ispUnallocate_DynamicWaveAlloc_byLoad)'
         GOTO RETURN_SP
      END

      -- Check if Pack Confirmed
      IF EXISTS (SELECT 1 FROM ORDERS OH WITH (NOLOCK)
                 INNER JOIN PACKHEADER PACHD (NOLOCK) ON (OH.LoadKey = PACHD.LoadKey AND PACHD.Storerkey = @c_Storerkey)
                 INNER JOIN PACKDETAIL PACDT (NOLOCK) ON (PACHD.PickSlipNo = PACDT.PickSlipNo AND PACDT.Storerkey = @c_Storerkey)
                 WHERE OH.UserDefine09 = @c_WaveKey 
                 AND   OH.Storerkey = @c_Storerkey
                 AND   isnull(PACHD.Loadkey,'')<>''
                 AND   isnull(OH.Loadkey,'')<>''
                 AND   OH.LoadKey = @c_LoadKey
                 AND   PACHD.Status = '9' ) -- Pack Confirmed
       BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 63009
         SELECT @c_errmsg = 'Pack Confirmed. Unallocation is Not Allowed (ispUnallocate_DynamicWaveAlloc_byLoad)'
         GOTO RETURN_SP
      END

      --Check if start replenishment(Bulk to DP,Bulk to PP, PP to DP)
     IF EXISTS(SELECT 1 FROM REPLENISHMENT RPL WITH (NOLOCK)
               WHERE ReplenNo=@c_wavekey
               AND Storerkey = @c_Storerkey
               AND Confirmed<>'W'
               AND Remark<>'FCP')
     BEGIN
        SET @cReplenStarted='Y'
     END

     --Check if Complete replenishment(Bulk to DP, PP to DP)
     IF NOT EXISTS(SELECT 1 FROM REPLENISHMENT RPL WITH (NOLOCK)
                   WHERE ReplenNo = @c_wavekey
                   AND Storerkey = @c_STorerkey
                   AND Confirmed  in('W','S')
                   AND Remark<>'FCP')
     BEGIN
        SET @cReplenDone = 'Y'
     END


     IF @cReplenStarted='N'
     BEGIN
       SELECT @n_continue = 3
       SELECT @n_err = 63010
       SELECT @c_errmsg = 'Replenishment not start.Please unallocate the whole wave (ispUnallocate_DynamicWaveAlloc_byLoad)'
       GOTO RETURN_SP
     END

     IF @cReplenStarted='Y' and @cReplenDone='N'
     BEGIN
       SELECT @n_continue = 3
       SELECT @n_err = 63011
       SELECT @c_errmsg = 'Replenishment not Done.Please Complete Replenishment then unallocate the LoadPlan (ispUnallocate_DynamicWaveAlloc_byLoad)'
       GOTO RETURN_SP 
     END
      -- Get PickSlipNo
      SET @c_PickSlipNo = ''
      SELECT @c_PickSlipNo = PickHeaderKey
      FROM PICKHEADER WITH (NOLOCK)
      WHERE isnull(ExternOrderKey,'') = @c_LoadKey

      /* ----------------------------------------------- */
      /* Create Temp Table                               */
      /* ----------------------------------------------- */
      DECLARE @tTempRESULT TABLE (
         GroupType          NVARCHAR(30) NULL,
         SKU                NVARCHAR(20) NULL,
         QTY                INT      NULL,
         LOC                NVARCHAR(10) NULL,
         ID                 NVARCHAR(18) NULL,
         PickSlipNo         NVARCHAR(10) NULL,
         CartonNo           INT      NULL,
         UCCNo              NVARCHAR(20) NULL,
         ReplenishmentGroup NVARCHAR(10) NULL)

      /* ----------------------------------------------- */
      /* INSERT Result Set                               */
      /* ----------------------------------------------- */
      -- GROUP1. PackDetail
      INSERT INTO @tTempRESULT
      SELECT 'PACKDETAIL Group', SKU, QTY, '', '', PickSlipNo, CartonNo, '', ''
      FROM PACKDETAIL WITH (NOLOCK)
      WHERE Storerkey = @c_Storerkey AND PickSlipNo = @c_PickSlipNo
      ORDER BY CartonNo, SKU
      -- GROUP2. UCC
      INSERT INTO @tTempRESULT
      SELECT DISTINCT 'UCC Group', RPL.SKU, RPL.QTY, RPL.FromLoc, RPL.ID, '', 0, RPL.RefNo, RPL.ReplenishmentGroup
      FROM ORDERS OH WITH (NOLOCK)
      INNER JOIN PACKHEADER PACHD WITH (NOLOCK) ON (OH.LoadKey = PACHD.LoadKey AND PACHD.Storerkey = @c_Storerkey)
      INNER JOIN PACKDETAIL PACDT WITH (NOLOCK) ON (PACHD.PickSlipNo = PACDT.PickSlipNo AND PACDT.Storerkey = @c_Storerkey)
      INNER JOIN REPLENISHMENT RPL WITH (NOLOCK) ON (RPL.ReplenNo = OH.UserDefine09 AND RPL.RefNo = PACDT.RefNo and RPL.Storerkey = @c_Storerkey)
      WHERE OH.UserDefine09 = @c_WaveKey 
      AND   OH.Storerkey = @c_Storerkey
      AND   isnull(PACHD.Loadkey,'')<>''
      AND   isnull(RPL.ReplenNo,'')<>''
      AND   isnull(RPL.RefNo,'')<>''
      AND   isnull(PACDT.RefNo,'')<>''
      AND   isnull(OH.LoadKey,'') = @c_LoadKey
      AND   RPL.ToLoc = 'PICK' -- FCP
      ORDER BY RPL.FromLoc, RPL.SKU

      /* ----------------------------------------------- */
      /* START UNALLOCATION                              */
      /* ----------------------------------------------- */
      -- 1. UPDATE UCC
      UPDATE UCC WITH (ROWLOCK) SET
         Status = '1',
         WaveKey = '',
         EditDate = GETDATE(),
			EditWho = sUSER_sNAME() 
      FROM ORDERS OH WITH (NOLOCK)
      INNER JOIN PACKHEADER PACHD WITH (NOLOCK) ON (OH.LoadKey = PACHD.LoadKey AND PACHD.Storerkey = @c_Storerkey)
      INNER JOIN PACKDETAIL PACDT WITH (NOLOCK) ON (PACHD.PickSlipNo = PACDT.PickSlipNo AND PACDT.Storerkey = @c_Storerkey)
      INNER JOIN REPLENISHMENT RPL WITH (NOLOCK) ON (RPL.ReplenNo = OH.UserDefine09 AND RPL.RefNo = PACDT.RefNo AND RPL.Storerkey = @c_Storerkey)
      INNER JOIN UCC UCC ON (UCC.UCCNo = RPL.RefNo AND UCC.Storerkey = @c_Storerkey)
      WHERE OH.UserDefine09 = @c_WaveKey 
      AND   OH.Storerkey = @c_Storerkey
      AND   isnull(PACHD.Loadkey,'')<>''
      AND   isnull(RPL.ReplenNo,'')<>''
      AND   isnull(RPL.RefNo,'')<>''
      AND   isnull(PACDT.RefNo,'')<>''
      AND   isnull(OH.LoadKey,'') = @c_LoadKey
      AND   RPL.ToLoc = 'PICK' -- FCP
      AND   UCC.Status in ('3','4','6')
      IF @@ERROR <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 63012
         SELECT @c_errmsg = 'UPDATE UCC failed (ispUnallocate_DynamicWaveAlloc_byLoad)'
         GOTO RETURN_SP
      END

      -- 2. DELETE REPLENISHMENT
      DELETE REPLENISHMENT
      FROM ORDERS OH WITH (NOLOCK)
      INNER JOIN PACKHEADER PACHD WITH (NOLOCK) ON (OH.LoadKey = PACHD.LoadKey AND PACHD.Storerkey = @c_Storerkey)
      INNER JOIN PACKDETAIL PACDT WITH (NOLOCK) ON (PACHD.PickSlipNo = PACDT.PickSlipNo AND PACDT.Storerkey = @c_Storerkey)
      INNER JOIN REPLENISHMENT RPL WITH (NOLOCK) ON (RPL.ReplenNo = OH.UserDefine09 AND RPL.RefNo = PACDT.RefNo AND RPL.Storerkey = @c_Storerkey)
      WHERE OH.UserDefine09 = @c_WaveKey
      AND   OH.Storerkey = @c_Storerkey
      AND   isnull(PACHD.Loadkey,'')<>''
      AND   isnull(RPL.ReplenNo,'')<>''
      AND   isnull(RPL.RefNo,'')<>''
      AND   isnull(PACDT.RefNo,'')<>''
      AND   isnull(OH.LoadKey,'') = @c_LoadKey
      AND   RPL.ToLoc = 'PICK' -- FCP
      IF @@ERROR <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 63013
         SELECT @c_errmsg = 'DELETE REPLENISHMENT failed (ispUnallocate_DynamicWaveAlloc_byLoad)'
         GOTO RETURN_SP
      END
      
      -- 3. Update Pickdetail Status
      UPDATE PICKDETAIL
      SET STATUS='2'
      FROM ORDERS OH WITH (NOLOCK)
      WHERE PICKDETAIL.ORDERKEY=OH.ORDERKEY
      AND   OH.UserDefine09 = @c_Wavekey
      AND   OH.Storerkey = @c_STorerkey
      AND   isnull(OH.Loadkey,'') = @c_Loadkey
      IF @@ERROR <> 0
      BEGIN
         SELECT @n_continue = 3
       SELECT @n_err = 63014
         SELECT @c_errmsg = 'UPDATE PICKDETAIL failed (ispUnallocate_DynamicWaveAlloc_byLoad)'
         GOTO RETURN_SP
      END

      -- 4. DELETE PICKHEADER
      DELETE PICKHEADER
      WHERE PickHeaderKey = @c_PickSlipNo
      IF @@ERROR <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 63015
         SELECT @c_errmsg = 'DELETE PICKHEADER failed (ispUnallocate_DynamicWaveAlloc_byLoad)'
         GOTO RETURN_SP
      END

      -- 5. DELETE PICKINGINFO
      DELETE PICKINGINFO
      WHERE PickSlipNo = @c_PickSlipNo
      IF @@ERROR <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 63016
         SELECT @c_errmsg = 'DELETE PICKINGINFO failed (ispUnallocate_DynamicWaveAlloc_byLoad)'
         GOTO RETURN_SP
         
      END
  
      -- 6. DELETE PACKDETAIL
      DELETE PACKDETAIL
      WHERE Storerkey = @c_Storerkey
      AND   PickSlipNo = @c_PickSlipNo
      IF @@ERROR <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 63017
         SELECT @c_errmsg = 'DELETE PACKDETAIL failed (ispUnallocate_DynamicWaveAlloc_byLoad)'
         GOTO RETURN_SP
      END
 
      -- PACKDETAIL is Empty
      IF NOT EXISTS (SELECT 1 FROM PACKDETAIL WITH (NOLOCK)
                     WHERE Storerkey = @c_Storerkey AND PickSlipNo = @c_PickSlipNo )
      BEGIN
         -- 7. DELETE PACKHEADER
         DELETE PACKHEADER 
         WHERE Storerkey = @c_Storerkey AND PickSlipNo = @c_PickSlipNo
         IF @@ERROR <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 63018
            SELECT @c_errmsg = 'DELETE PACKHEADER failed (ispUnallocate_DynamicWaveAlloc_byLoad)'
            GOTO RETURN_SP
         END
      END

      /* ----------------------------------------------- */
      /* RETURN Result Set                               */
      /* ----------------------------------------------- */
      SELECT GroupType, SKU, QTY, LOC, ID, PickSlipNo, CartonNo, UCCNo, ReplenishmentGroup
      FROM @tTempRESULT

   END -- IF @n_continue = 1 OR @n_continue = 2

   RETURN_SP:

   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispUnallocate_DynamicWaveAlloc_byLoad'
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
END



SET QUOTED_IDENTIFIER OFF 

GO