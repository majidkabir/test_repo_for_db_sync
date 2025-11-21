SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispUnallocate_DynamicWaveAlloc_bySKU               */
/* Creation Date: 11-Aug-2008                                           */
/* Copyright: IDS                                                       */
/* Written by: wwang                                                    */
/*                                                                      */
/* Purpose: CN NIKE Bridge - Unallocate Dynamic Wave Allocation by SKU  */
/*                                                                      */
/* Input Parameters:  @c_Storerkey   NVARCHAR(15)							   */
/*              ,@c_wavekey          NVARCHAR(10)							   */
/*							,@c_sku              NVARCHAR(20)					   */
/*                                                                      */
/* Output Parameters: Report                                            */
/*                                                                      */
/* Return Status: NONE                                                  */
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
/* 2018-12-15   TLTING01    remove extra set ansi at the end sp         */
/************************************************************************/
--exec ispUnallocate_DynamicWaveAlloc_bySKU '0000000145','207101010xxl'
CREATE PROC  [dbo].[ispUnallocate_DynamicWaveAlloc_bySKU]
   @c_Storerkey NVARCHAR(15),
   @c_WaveKey  NVARCHAR(10),
   @c_SKU      NVARCHAR(20)
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
      @cPackingStarted NVARCHAR(1),
      @Curs            Cursor,
      @c_Loadkey         NVARCHAR(10),
      @c_PickSlipNo    NVARCHAR(10)

   SET @cPackingStarted = 'N'

   SELECT @n_starttcnt=@@TRANCOUNT, @n_continue=1, @b_success=0, @n_err=0, @c_errmsg='', @b_debug=0

   BEGIN TRAN

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      -- If NULL set WaveKey to blank
      IF ISNULL(RTRIM(@c_WaveKey),'') = ''
         SET @c_WaveKey = ''

      -- If NULL set LoadKey to blank
      IF ISNULL(RTRIM(@c_SKU),'') = ''
         SET @c_SKU = ''

      -- Check if blank WaveKey
      IF @c_WaveKey = ''
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 63001
         SELECT @c_errmsg = 'Empty WaveKey (ispUnallocate_DynamicWaveAlloc_bySKU)'
         GOTO RETURN_SP
      END

      -- Check if blank SKU
      IF @c_SKU = ''
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 63002
         SELECT @c_errmsg = 'Empty SKU (ispUnallocate_DynamicWaveAlloc_bySKU)'
         GOTO RETURN_SP
      END

      -- Check if WaveKey exists
      IF NOT EXISTS (SELECT 1 FROM WAVE WITH (NOLOCK)
                     WHERE WaveKey = @c_WaveKey )
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 63003
         SELECT @c_errmsg = 'WaveKey Not Found (ispUnallocate_DynamicWaveAlloc_bySKU)'
         GOTO RETURN_SP
      END

      -- Check if WaveDetail exists
      IF NOT EXISTS (SELECT 1 FROM WAVEDETAIL WITH (NOLOCK)
                     WHERE WaveKey = @c_WaveKey )
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 63004
         SELECT @c_errmsg = 'WaveDetail Not Found (ispUnallocate_DynamicWaveAlloc_bySKU)'
         GOTO RETURN_SP
      END

      -- Check if WaveKey closed
      IF EXISTS (SELECT 1 FROM WAVE WITH (NOLOCK)
                  WHERE WaveKey = @c_WaveKey
                  AND   Status = '9' )
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 63005
         SELECT @c_errmsg = 'WaveKey Closed (ispUnallocate_DynamicWaveAlloc_bySKU)'
         GOTO RETURN_SP
      END

      -- Check if SKU exists in Wave
      IF NOT EXISTS (SELECT 1 FROM ORDERS OH WITH (NOLOCK)
                     INNER JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OH.OrderKey = OD.OrderKey)
                     WHERE OH.UserDefine09 = @c_WaveKey
                     AND   OH.Storerkey = @c_STorerkey
                     AND   OD.SKU = @c_SKU )
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 63006
         SELECT @c_errmsg = 'SKU Not Found in Wave (ispUnallocate_DynamicWaveAlloc_bySKU)'
         GOTO RETURN_SP
      END

/*
      -- Any allocation
      IF NOT EXISTS (SELECT 1 FROM ORDERS OH WITH (NOLOCK)
                     INNER JOIN PICKDETAIL PD WITH (NOLOCK) ON (OH.OrderKey = PD.OrderKey)
                     WHERE OH.UserDefine09 = @c_WaveKey 
                     AND   PD.SKU = @c_SKU
                     AND   PD.Status  = '0' )
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 63007
         SELECT @c_errmsg = 'No Order to Unallocate for the SKU (ispUnallocate_DynamicWaveAlloc_bySKU)'
         GOTO RETURN_SP
      END
*/

      -- Check if Pack Confirmed
      IF EXISTS (SELECT 1 FROM ORDERS OH WITH (NOLOCK)
                 INNER JOIN PACKHEADER PACHD (NOLOCK) ON (OH.LoadKey = PACHD.LoadKey AND PACHD.Storerkey = @c_Storerkey)
                 INNER JOIN PACKDETAIL PACDT (NOLOCK) ON (PACHD.PickSlipNo = PACDT.PickSlipNo AND PACDT.Storerkey = @c_Storerkey)
                 WHERE OH.UserDefine09 = @c_WaveKey 
                 AND   OH.Storerkey = @c_Storerkey
                 AND   isnull(PACHD.Loadkey,'')<>''
                 AND   isnull(OH.Loadkey,'')<>''
                 AND   PACHD.Status = '9' ) -- Pack Confirmed
       BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 63008
         SELECT @c_errmsg = 'Pack Confirmed. Unallocation is Not Allowed (ispUnallocate_DynamicWaveAlloc_bySKU)'
         GOTO RETURN_SP
      END

      IF EXISTS (SELECT 1 FROM PACKDETAIL PACDT WITH (NOLOCK)
                 INNER JOIN PACKHEADER PACHD (NOLOCK) ON (PACDT.Pickslipno=PACHD.Pickslipno AND PACHD.Storerkey = @c_Storerkey)
                 INNER JOIN ORDERS OH (NOLOCK) ON (PACHD.Loadkey=OH.Loadkey AND OH.Storerkey = @c_Storerkey)
                 WHERE OH.UserDefine09=@c_Wavekey 
                 AND   PACDT.Storerkey = @c_Storerkey
                 AND   isnull(PACHD.Loadkey,'')<>''
                 AND   isnull(OH.Loadkey,'')<>''
                 AND   PACDT.SKU = @c_SKU
                 AND   ISNULL(PACDT.RefNo,'')='')--Start packing
      BEGIN
        SET @cPackingStarted='Y'
      END

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
      -- GROUP1. PICKDETAIL
      INSERT INTO @tTempRESULT
      SELECT 'PICKDETAIL Group', PD.SKU, PD.QTY, PD.LOC, PD.ID, '', 0, '', ''
      FROM ORDERS OH WITH (NOLOCK)
      INNER JOIN PICKDETAIL PD WITH (NOLOCK) ON (OH.OrderKey = PD.OrderKey AND PD.Storerkey = @c_Storerkey)
      WHERE OH.UserDefine09 = @c_Wavekey
      AND   OH.Storerkey = @c_Storerkey
      AND   PD.SKU = @c_SKU
      ORDER BY PD.LOC, PD.SKU

      -- GROUP2. PACKDETAIL
      INSERT INTO @tTempRESULT
      SELECT 'PACKDETAIL Group', SKU, QTY, '', '', PACDT.PickSlipNo, CartonNo, '', ''
      FROM PACKDETAIL PACDT WITH (NOLOCK) 
      INNER JOIN PACKHEADER PACHD WITH(NOLOCK) ON (PACDT.PickslipNo=PACHD.PickSlipno AND PACHD.Storerkey = @c_Storerkey)
      INNER JOIN ORDERS OH WITH(NOLOCK) ON (PACHD.Loadkey=OH.Loadkey AND OH.Storerkey = @c_Storerkey)
      WHERE OH.UserDefine09=@c_Wavekey 
      AND   PACDT.Storerkey = @c_Storerkey
      AND   isnull(PACHD.Loadkey,'')<>''
      AND   isnull(OH.Loadkey,'')<>''
      AND   PACDT.SKU = @c_SKU
      ORDER BY CartonNo, SKU

      -- GROUP3. UCC
      INSERT INTO @tTempRESULT
      SELECT DISTINCT 'UCC Group', RPL.SKU, RPL.QTY, RPL.FromLoc, RPL.ID, '', 0, RPL.RefNo, RPL.ReplenishmentGroup
      FROM ORDERS OH WITH (NOLOCK)
      INNER JOIN REPLENISHMENT RPL WITH (NOLOCK) ON (RPL.ReplenNo = OH.UserDefine09 AND RPL.Storerkey = @c_Storerkey)
      WHERE OH.UserDefine09 = @c_WaveKey
      AND   OH.Storerkey = @c_Storerkey
      AND   Isnull(RPL.ReplenNo,'')<>''
      AND   RPL.SKU = @C_SKU
      AND   (Case When @cPackingStarted='Y' and RPL.toLoc='PICK' then 1
                  When @cPackingStarted='N'  and Remark in('Bulk to DP','FCP') then 1
                  When RPL.Confirmed='W' and Remark='Bulk to PP' then 1
                  Else 0 end)=1
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
      INNER JOIN REPLENISHMENT RPL WITH (NOLOCK) ON (RPL.ReplenNo = OH.UserDefine09 AND RPL.Storerkey = @c_Storerkey)
      INNER JOIN UCC UCC ON (UCC.UCCNo = RPL.RefNo AND UCC.Storerkey = @c_Storerkey)
      WHERE OH.UserDefine09 = @c_WaveKey 
      AND  OH.Storerkey = @c_Storerkey
      AND  isnull(RPL.ReplenNo,'')<>'' 
      AND  isnull(RPL.RefNo,'')<>''
      AND  RPL.SKU = @c_SKU
      AND  (Case When @cPackingStarted='Y' and RPL.toLoc='PICK' then 1
                 When @cPackingStarted='N'  and Remark in('Bulk to DP','FCP') then 1
                 When RPL.Confirmed='W' and Remark='Bulk to PP' then 1
                 Else 0 end)=1
      IF @@ERROR <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 63009
         SELECT @c_errmsg = 'UPDATE UCC failed (ispUnallocate_DynamicWaveAlloc_bySKU)'
         GOTO RETURN_SP
      END

      -- 2. DELETE REPLENISHMENT
      DELETE REPLENISHMENT
      WHERE ReplenNo = @c_WaveKey 
      AND   Storerkey = @c_Storerkey
      AND   SKU = @c_SKU
      AND  (Case when Remark<>'Bulk to PP' then 1
                 when Remark='Bulk to PP' and Confirmed='W' then 1
                 else 0 end)=1 
      IF @@ERROR <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 63010
         SELECT @c_errmsg = 'DELETE REPLENISHMENT failed (ispUnallocate_DynamicWaveAlloc_bySKU)'
         GOTO RETURN_SP
      END

      -- 3. DELETE PACKDETAIL
      DELETE PACKDETAIL
      FROM ORDERS OH
      INNER JOIN PACKHEADER PACHD WITH (NOLOCK) ON (OH.LoadKey = PACHD.LoadKey ANd PACHD.Storerkey = @c_Storerkey)
      INNER JOIN PACKDETAIL PACDT WITH (NOLOCK) ON (PACHD.PickSlipNo = PACDT.PickSlipNo AND PACDT.Storerkey = @c_Storerkey)
      WHERE OH.UserDefine09 = @c_Wavekey 
      AND   OH.Storerkey = @c_Storerkey
      AND   isnull(PACHD.Loadkey,'')<>''
      AND   isnull(OH.Loadkey,'')<>''
      AND   PACDT.SKU = @c_SKU
      IF @@ERROR <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 63011
         SELECT @c_errmsg = 'DELETE PACKDETAIL failed (ispUnallocate_DynamicWaveAlloc_bySKU)'
         GOTO RETURN_SP
      END

      -- 4. DELETE PICKDETAIL
      UPDATE PICKDETAIL
      SET STATUS='2'
      FROM ORDERS OH
      INNER JOIN PICKDETAIL PD WITH (NOLOCK) ON (OH.OrderKey = PD.OrderKey ANd PD.Storerkey = @c_Storerkey)
      WHERE OH.UserDefine09 = @c_WaveKey
      AND   OH.Storerkey = @c_Storerkey
      AND   PD.SKU=@c_SKU

      DELETE PICKDETAIL
      FROM ORDERS OH
      INNER JOIN PICKDETAIL PD WITH (NOLOCK) ON (OH.OrderKey = PD.OrderKey AND PD.Storerkey = @c_Storerkey)
      WHERE OH.UserDefine09 = @c_WaveKey
      AND   OH.Storerkey = @c_Storerkey
      AND   PD.SKU = @c_SKU
      AND   PD.STATUS='2'
      IF @@ERROR <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 63012
         SELECT @c_errmsg = 'DELETE PICKDETAIL failed (ispUnallocate_DynamicWaveAlloc_bySKU)'
         GOTO RETURN_SP
      END

      --Insert Loadkey(only one SKU) into TempTable
      SET @curs=cursor Scroll for
      SELECT DISTINCT TA.LOADkey
      from (
      SELECT OH.Loadkey
      FROM ORDERDETAIL OD WITH (NOLOCK)
      INNER JOIN ORDERS OH WITH (NOLOCK) ON (OD.Orderkey = OH.Orderkey)
      WHERE OH.Userdefine09 = @c_Wavekey
      AND   OH.Storerkey = @c_Storerkey
      AND   isnull(OH.Loadkey,'')<>''
      AND   SKU = @c_SKU) AS TA INNER JOIN ORDERDETAIL AS TB WITH (NOLOCK) ON TA.Loadkey=TB.Loadkey
      GROUP BY TA.Loadkey
      Having Count(Distinct TB.SKU)=1
      Open @curs
      fetch next from @curs into @c_Loadkey
      while @@FETCH_STATUS=0
      begin  

        SET @c_PickSlipNo = ''
        SELECT @c_PickSlipNo = PickHeaderKey
        FROM PICKHEADER WITH (NOLOCK)
        WHERE ExternOrderKey = @c_LoadKey
        And   isnull(@c_Loadkey,'')<>''

         -- 5. DELETE PACKHEADER
         DELETE PACKHEADER WHERE Storerkey = @c_Storerkey AND PickSlipNo = @c_PickSlipNo
         IF @@ERROR <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 63013
            SELECT @c_errmsg = 'DELETE PACKHEADER failed (ispUnallocate_DynamicWaveAlloc_bySKU)'
            GOTO RETURN_SP
         END


         -- 6. DELETE PICKINGINFO
         DELETE PICKINGINFO
         WHERE PickSlipNo = @c_PickSlipNo
         IF @@ERROR <> 0
         BEGIN
           SELECT @n_continue = 3
           SELECT @n_err = 63014
           SELECT @c_errmsg = 'DELETE PICKINGINFO failed (ispUnallocate_DynamicWaveAlloc_bySKU)'
           GOTO RETURN_SP 
         END

         --7. DELETE PICKHEADER
         DELETE PICKHEADER WHERE PickHeaderkey = @c_PickSlipNo
         IF @@ERROR <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 63015
            SELECT @c_errmsg = 'DELETE PICKHEADER failed (ispUnallocate_DynamicWaveAlloc_bySKU)'
            GOTO RETURN_SP
         END


        -- 8. DELETE LOADPLAN -- Trigger DELETE LoadplanDetail, UPDATE Orders.LoadKey = ''
        DELETE LOADPLAN WHERE Loadkey = @c_Loadkey
        IF @@ERROR <> 0
        BEGIN
           SELECT @n_continue = 3
           SELECT @n_err = 63016
           SELECT @c_errmsg = 'DELETE LOADPLAN failed (ispUnallocate_DynamicWaveAlloc_bySKU)'
           GOTO RETURN_SP
        END

    Fetch next from @curs into @c_Loadkey
    End   

      

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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispUnallocate_DynamicWaveAlloc_bySKU'
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


GO