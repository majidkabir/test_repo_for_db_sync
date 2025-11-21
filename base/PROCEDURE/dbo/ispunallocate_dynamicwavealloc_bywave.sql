SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispUnallocate_DynamicWaveAlloc_byWave              */
/* Creation Date: 11-Aug-2008                                           */
/* Copyright: IDS                                                       */
/* Written by: wwang                                                    */
/*                                                                      */
/* Purpose: CN NIKE Bridge - Unallocate Dynamic Wave Allocation by Wave */
/*                                                                      */
/* Input Parameters:  @c_Storerkey NVARCHAR(15)                         */
/*                   ,@c_wavekey   NVARCHAR(10)                         */
/*                                                                      */
/* Output Parameters: Report                                            */
/*                                                                      */
/* Return Status: NONE                                                  */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By: Brio Report                                               */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author      Purposes                                    */
/* 03-12-2008   wwang       add Storerkey as parameter                  */
/* 18-06-2010   Leong       SOS# 178258 - Performance tuning            */
/* 01-08-2011   TLTING      Tune Commit by Line                         */
/* 23-11-2011   ChewKP      Bug Fixes (ChewKP01)                        */
/* 22-02-2017   TLTING      Performance tune                            */
/* 12-12-2019   WLChooi     WMS-11402 - New Storerconfig                */
/*                          UnallocateWaveRetainLoad - Skip removing    */
/*                          load plan after unallocating the wave (WL01)*/
/* 04-06-2021   SPChin      INC1379321 - Bug Fixed                      */
/* 25-01-2022   Wan01       LFWM-3146 - UAT - TW  Pick Management -Order*/
/*                          Unallocation - cannot  unallocate order at  */
/*                          once                                        */
/* 25-01-2022   Wan01       DevOps Combine Script                       */
/************************************************************************/

CREATE PROC  [dbo].[ispUnallocate_DynamicWaveAlloc_byWave]
   @c_Storerkey NVARCHAR(15),
   @c_WaveKey   NVARCHAR(10)
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
      @cPackingStarted NVARCHAR(1)

   DECLARE @c_UCCNo   NVARCHAR(20),
     @c_ReplenishmentKey NVARCHAR(10),
     @c_PickSlipNo       NVARCHAR(10),
     @c_SKU           NVARCHAR(20),
     @c_Loadkey          NVARCHAR(10),
     @c_PickdetailKey    NVARCHAR(10)
     
    , @n_UCC_RowRef   INT = 0                --(Wan01)
   SET @cPackingStarted = 'N'

   SELECT @n_starttcnt=@@TRANCOUNT, @n_continue=1, @b_success=0, @n_err=0, @c_errmsg='', @b_debug=0

   --BEGIN TRAN

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      -- If NULL set WaveKey to blank
      IF ISNULL(RTRIM(@c_WaveKey),'') = ''
         SET @c_WaveKey = ''


      -- Check if blank WaveKey
      IF @c_WaveKey = ''
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 63001
         SELECT @c_errmsg = 'Empty WaveKey (ispUnallocate_DynamicWaveAlloc_byWave)'
         GOTO RETURN_SP
      END

      -- Check if WaveKey exists
      IF NOT EXISTS (SELECT 1 FROM WAVE WITH (NOLOCK)
                     WHERE WaveKey = @c_WaveKey )
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 63002
         SELECT @c_errmsg = 'WaveKey Not Found (ispUnallocate_DynamicWaveAlloc_byWave)'
         GOTO RETURN_SP
      END

      -- Check if WaveDetail exists
      IF NOT EXISTS (SELECT 1 FROM WAVEDETAIL WITH (NOLOCK)
                     WHERE WaveKey = @c_WaveKey )
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 63003
         SELECT @c_errmsg = 'WaveDetail Not Found (ispUnallocate_DynamicWaveAlloc_byWave)'
         GOTO RETURN_SP
      END

      -- Check if WaveKey closed
      IF EXISTS (SELECT 1 FROM WAVE WITH (NOLOCK)
                  WHERE WaveKey = @c_WaveKey
                  AND   Status = '9' )
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 63004
         SELECT @c_errmsg = 'WaveKey Closed (ispUnallocate_DynamicWaveAlloc_byWave)'
         GOTO RETURN_SP
      END

      --WL01 Start
      DECLARE @c_facility                 NVARCHAR(5)  = '',  
              @c_UnallocateWaveRetainLoad NVARCHAR(30) = ''

      SELECT TOP 1 @c_facility = ISNULL(OH.Facility,'')
      FROM ORDERS OH (NOLOCK)
      WHERE OH.UserDefine09 = @c_Wavekey 
      AND OH.Storerkey = @c_StorerKey

      EXECUTE nspGetRight @c_facility,    -- facility    
                          @c_StorerKey,   -- StorerKey    
                          NULL,           -- Sku    
                          'UnallocateWaveRetainLoad',  -- Configkey    
                          @b_success    OUTPUT,    
                          @c_UnallocateWaveRetainLoad  OUTPUT,    
                          @n_err        OUTPUT,    
                          @c_errmsg     OUTPUT  

      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 63005
         SELECT @c_errmsg = 'Error executing nspGetRight (ispUnallocate_DynamicWaveAlloc_byWave)'
         GOTO RETURN_SP
      END
      --WL01 End


/*
      -- Any allocation
      IF NOT EXISTS (SELECT 1 FROM ORDERS OH WITH (NOLOCK)
                     INNER JOIN PICKDETAIL PD WITH (NOLOCK) ON (OH.OrderKey = PD.OrderKey)
                     WHERE OH.UserDefine09 = @c_WaveKey
                     AND   PD.Status  < '5' )
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 63005
         SELECT @c_errmsg = 'No Order to Unallocate (ispUnallocate_DynamicWaveAlloc_byWave)'
         GOTO RETURN_SP
      END
*/

      -- Check if Pack Confirmed

       -- tlting perfromance tune
      IF EXISTS ( SELECT 1 FROM ( SELECT PACHD.Loadkey FROM  PACKDETAIL PACDT WITH (NOLOCK)
               INNER JOIN PACKHEADER PACHD (NOLOCK) ON  (PACDT.Pickslipno = PACHD.Pickslipno )
               WHERE PACHD.Storerkey = @c_Storerkey AND    isnull(PACHD.Loadkey,'')<>'' AND  ISNULL(PACDT.RefNo,'')='' 
               AND   PACHD.Status = '9'
               GROUP BY PACHD.Loadkey ) AS B
               INNER JOIN ( Select OH.Loadkey 
               FROM  ORDERS OH (NOLOCK) where OH.UserDefine09 = @c_Wavekey AND  OH.Storerkey = @C_Storerkey
               GROUP BY OH.Loadkey ) As A ON A.Loadkey =  B.Loadkey
                  ) -- Pack Confirmed
       BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 63006
         SELECT @c_errmsg = 'Pack Confirmed. Unallocation is Not Allowed (ispUnallocate_DynamicWaveAlloc_byWave)'
         GOTO RETURN_SP
      END

      -- tlting perfromance tune
      IF EXISTS (SELECT 1 FROM ( SELECT PACHD.Loadkey FROM  PACKDETAIL PACDT WITH (NOLOCK)
               INNER JOIN PACKHEADER PACHD (NOLOCK) ON  (PACDT.Pickslipno = PACHD.Pickslipno )
               WHERE PACHD.Storerkey = @c_Storerkey AND    isnull(PACHD.Loadkey,'')<>'' AND  ISNULL(PACDT.RefNo,'')='' 
               GROUP BY PACHD.Loadkey ) AS B
               INNER JOIN ( Select OH.Loadkey 
               FROM  ORDERS OH (NOLOCK) where OH.UserDefine09 = @c_Wavekey AND  OH.Storerkey = @C_Storerkey
               GROUP BY OH.Loadkey ) As A ON A.Loadkey =  B.Loadkey)--Start packing
      BEGIN
        SET @cPackingStarted='Y'
      END

      WHILE @@TRANCOUNT > 0
      BEGIN
         COMMIT TRAN
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
      ORDER BY PD.LOC, PD.SKU

      -- GROUP2. PACKDETAIL
      INSERT INTO @tTempRESULT
      SELECT  'PACKDETAIL Group', PACDT.SKU, PACDT.QTY, '', '', PACDT.PickSlipNo, PACDT.CartonNo, '', ''
      FROM    PACKDETAIL PACDT   (NOLOCK)               
      INNER JOIN ( Select PACHD.PickSlipNo 
      FROM  ORDERS OH (NOLOCK) 
      JOIN PACKHEADER PACHD WITH (NOLOCK) ON OH.Loadkey =  PACHD.Loadkey
      WHERE OH.UserDefine09 = @c_Wavekey AND  OH.Storerkey = @C_Storerkey
       AND    isnull(PACHD.Loadkey,'')<>''  AND PACHD.Storerkey = OH.Storerkey
         AND   isnull(OH.Loadkey,'')<>''
      GROUP BY PACHD.PickSlipNo ) As A ON A.PickSlipNo =  PACDT.PickSlipNo
      ORDER BY PACDT.CartonNo, PACDT.SKU

/*
      SELECT 'PACKDETAIL Group', SKU, QTY, '', '', PACDT.PickSlipNo, CartonNo, '', ''
      FROM PACKDETAIL PACDT WITH (NOLOCK)
      INNER JOIN PACKHEADER PACHD WITH(NOLOCK) ON (PACDT.PickslipNo=PACHD.PickSlipno AND PACHD.Storerkey =  @c_Storerkey)
      INNER JOIN ORDERS OH WITH(NOLOCK) ON (PACHD.Loadkey=OH.Loadkey AND OH.Storerkey = @c_Storerkey)
      WHERE OH.UserDefine09 = @c_Wavekey
      AND   PACDT.Storerkey = @c_Storerkey
      AND   isnull(PACHD.Loadkey,'')<>''
      AND   isnull(OH.Loadkey,'')<>''
      ORDER BY CartonNo, SKU  */

      -- GROUP3. UCC
      INSERT INTO @tTempRESULT
      SELECT DISTINCT 'UCC Group', RPL.SKU, RPL.QTY, RPL.FromLoc, RPL.ID, '', 0, RPL.RefNo, RPL.ReplenishmentGroup
      FROM ORDERS OH WITH (NOLOCK)
      INNER JOIN REPLENISHMENT RPL WITH (NOLOCK) ON (RPL.ReplenNo = OH.UserDefine09 AND RPL.Storerkey = @c_Storerkey)
      WHERE (Case When @cPackingStarted='Y' and RPL.toLoc='PICK' then 1
                  When @cPackingStarted='N'  and Remark in('Bulk to DP','FCP') then 1
                  When RPL.Confirmed='W' and Remark='Bulk to PP' then 1
                  Else 0 end)=1
             AND Isnull(RPL.ReplenNo,'')<>''
             AND OH.UserDefine09 = @c_WaveKey
             AND OH.Storerkey = @c_Storerkey
      ORDER BY RPL.FromLoc, RPL.SKU


      /* ----------------------------------------------- */
      /* START UNALLOCATION                              */
      /* ----------------------------------------------- */
      -- 1. UPDATE UCC
      DECLARE Cursor_UCC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT UCC.UCCNo
               ,UCC.UCC_RowRef                                             --(Wan01)
      FROM ORDERS OH WITH (NOLOCK)
      INNER JOIN REPLENISHMENT RPL WITH (NOLOCK) ON (RPL.ReplenNo = OH.UserDefine09 AND RPL.Storerkey =  @c_Storerkey)
      INNER JOIN UCC UCC (NOLOCK) ON (UCC.UCCNo = RPL.RefNo)
      WHERE OH.UserDefine09 = @c_WaveKey
      AND   OH.Storerkey = @c_Storerkey
      AND   Isnull(RPL.RefNo,'')<>''
      AND   Isnull(RPL.ReplenNo,'')<>''
      AND  (Case When @cPackingStarted='Y' and RPL.toLoc='PICK' then 1
                 When @cPackingStarted='N'  and Remark in('Bulk to DP','FCP') then 1
                 When RPL.Confirmed='W' and Remark='Bulk to PP' then 1
                 Else 0 end)=1
      ORDER BY UCC.UCC_RowRef                                              --(Wan01) Sort to update
      OPEN Cursor_UCC 
         
      FETCH NEXT FROM Cursor_UCC INTO @c_UCCNo, @n_UCC_RowRef              --(Wan01)
      WHILE @@FETCH_STATUS <> -1
      BEGIN   
          BEGIN TRAN   
  
         UPDATE UCC WITH (ROWLOCK) SET
             Status = '1',
             WaveKey = '',
            EditDate = GETDATE(),
            EditWho = sUSER_sNAME()
          --WHERE UCC.UCCNo = UCC.UCCNo                                    --(Wan01) Update by  UCC_RowRef
         WHERE UCC_RowRef = @n_UCC_RowRef                                  --(Wan01) Update by  UCC_RowRef
         
          IF @@ERROR <> 0
          BEGIN
             SELECT @n_continue = 3
             SELECT @n_err = 63007
             SELECT @c_errmsg = 'UPDATE UCC failed (ispUnallocate_DynamicWaveAlloc_byWave)'
             GOTO RETURN_SP
          END
        ELSE  
        BEGIN  
           COMMIT TRAN  
        END           

         FETCH NEXT FROM Cursor_UCC INTO @c_UCCNo, @n_UCC_RowRef           --(Wan01)
      END
      CLOSE Cursor_UCC 
      DEALLOCATE Cursor_UCC 
      
      -- 2. DELETE REPLENISHMENT
      DECLARE Cursor_REP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT ReplenishmentKey
      FROM REPLENISHMENT WITH (NOLOCK) -- SOS# 178258
      WHERE  ReplenNo = @c_WaveKey
      AND   Storerkey = @c_Storerkey
      AND   (Case when Remark <> 'Bulk to PP' then 1
                  when Remark =  'Bulk to PP' and Confirmed='W' then 1
                  else 0 end)=1  
      ORDER BY ReplenishmentKey                                            --(Wan01) Sort to delete   
                
      OPEN Cursor_REP 
         
      FETCH NEXT FROM Cursor_REP INTO @c_ReplenishmentKey
      WHILE @@FETCH_STATUS <> -1
      BEGIN   
           BEGIN TRAN   
                  
         DELETE REPLENISHMENT WITH (ROWLOCK) 
         WHERE  ReplenishmentKey = @c_ReplenishmentKey
         IF @@ERROR <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 63008
            SELECT @c_errmsg = 'DELETE REPLENISHMENT failed (ispUnallocate_DynamicWaveAlloc_byWave)'
            GOTO RETURN_SP
         END
        ELSE  
        BEGIN  
           COMMIT TRAN  
        END           

         FETCH NEXT FROM Cursor_REP INTO @c_ReplenishmentKey
      END
      CLOSE Cursor_REP 
      DEALLOCATE Cursor_REP       

      -- 4. DELETE PICKDETAIL
      
      --DECLARE Cursor_PICKDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    --INC1379321
      DECLARE Cursor_PICKDETAIL CURSOR LOCAL STATIC READ_ONLY FOR            --INC1379321
      SELECT PD.PickdetailKey
      FROM  ORDERS OH WITH (NOLOCK)
      INNER JOIN PICKDETAIL PD WITH (NOLOCK) ON (OH.OrderKey = PD.OrderKey AND PD.Storerkey = @c_Storerkey)
      WHERE OH.UserDefine09 = @c_WaveKey
      AND   OH.Storerkey = @c_Storerkey
      ORDER BY PD.PickdetailKey                                            --(Wan01) Sort to delete
                                                                              
      OPEN Cursor_PICKDETAIL 
         
      FETCH NEXT FROM Cursor_PICKDETAIL INTO @c_PickdetailKey
      WHILE @@FETCH_STATUS <> -1
      BEGIN   
           BEGIN TRAN   
         
         /*          
      UPDATE PICKDETAIL WITH (ROWLOCK) -- SOS# 178258
      SET STATUS='2'
      FROM ORDERS OH
      INNER JOIN PICKDETAIL PD ON (OH.OrderKey = PD.OrderKey AND PD.Storerkey = @c_Storerkey)
      WHERE OH.UserDefine09 = @c_WaveKey
      AND   OH.Storerkey = @c_Storerkey
   */
   
         DELETE PICKDETAIL WITH (ROWLOCK) -- SOS# 178258
         WHERE PickdetailKey = @c_PickdetailKey
         IF @@ERROR <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 63010
            SELECT @c_errmsg = 'DELETE PICKDETAIL failed (ispUnallocate_DynamicWaveAlloc_byWave)'
            GOTO RETURN_SP
         END
         ELSE  
         BEGIN  
           COMMIT TRAN  
         END          

         FETCH NEXT FROM Cursor_PICKDETAIL INTO @c_PickdetailKey
      END
      CLOSE Cursor_PICKDETAIL 
      DEALLOCATE Cursor_PICKDETAIL   
      

     SELECT DISTINCT PACHD.PickSlipNo
     INTO #Temp_Pickslip
     FROM  ORDERS OH WITH (NOLOCK)
     INNER JOIN PACKHEADER PACHD WITH (NOLOCK) ON (OH.Loadkey = PACHD.Loadkey AND PACHD.Storerkey = @c_Storerkey)
     WHERE OH.UserDefine09 = @c_WaveKey
     AND   OH.Storerkey = @c_Storerkey
     AND   isnull(PACHD.Loadkey,'')<>''
     AND   isnull(OH.Loadkey,'')<>''
     UNION
     SELECT DISTINCT PH.PICKHEADERKey   
     FROM ORDERS OH WITH (NOLOCK)
     INNER JOIN PICKHEADER PH WITH (NOLOCK) ON (OH.Loadkey = PH.ExternOrderkey)
     WHERE OH.UserDefine09 = @c_WaveKey
     AND   OH.Storerkey = @c_Storerkey
     AND   isnull(OH.Loadkey,'')<>''
     AND   isnull(PH.Externorderkey,'')<>''
      
      
      -- 5. DELETE PACKHEADER
      DECLARE Cursor_PickSlip CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PickSlipNo
      FROM  #Temp_Pickslip
      ORDER BY PickSlipNo                                                  --(Wan01) Sort to delete
      
      OPEN Cursor_PickSlip 
         
      FETCH NEXT FROM Cursor_PickSlip INTO @c_PickSlipNo
      WHILE @@FETCH_STATUS <> -1
      BEGIN   
         BEGIN TRAN   

         DECLARE Cursor_PACKDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PACDT.SKU
         FROM ORDERS OH WITH (NOLOCK)
         INNER JOIN PACKHEADER PACHD WITH (NOLOCK) ON (OH.LoadKey = PACHD.LoadKey AND PACHD.Storerkey = @c_Storerkey)
         INNER JOIN PACKDETAIL PACDT WITH (NOLOCK) ON (PACHD.PickSlipNo = PACDT.PickSlipNo AND PACDT.Storerkey = @c_Storerkey)
         WHERE PACDT.PickSlipNo  = @c_PickSlipNo
         GROUP BY PACDT.SKU
         ORDER BY PACDT.SKU                                                --(Wan01) Sort to delete         

         OPEN Cursor_PACKDETAIL 
            
         FETCH NEXT FROM Cursor_PACKDETAIL INTO @c_SKU
         WHILE @@FETCH_STATUS <> -1
         BEGIN   
            BEGIN TRAN   
                     
            DELETE PACKDETAIL WITH (ROWLOCK) -- SOS# 178258
            WHERE PickSlipNo = @c_PickSlipNo
            AND SKU =  @c_SKU
            IF @@ERROR <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 63009
               SELECT @c_errmsg = 'DELETE PACKDETAIL failed (ispUnallocate_DynamicWaveAlloc_byWave)'
               GOTO RETURN_SP
            END
            FETCH NEXT FROM Cursor_PACKDETAIL INTO @c_SKU
         END
         CLOSE Cursor_PACKDETAIL 
         DEALLOCATE Cursor_PACKDETAIL   
                           
         DELETE PACKHEADER WITH (ROWLOCK) -- SOS# 178258
         WHERE PickSlipNo = @c_PickSlipNo
         IF @@ERROR <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 63011
            SELECT @c_errmsg = 'DELETE PACKHEADER failed (ispUnallocate_DynamicWaveAlloc_byWave)'
            GOTO RETURN_SP
         END

         DELETE PICKINGINFO WITH (ROWLOCK) -- SOS# 178258
         WHERE PickSlipNo = @c_PickSlipNo
         IF @@ERROR <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 63012
            SELECT @c_errmsg = 'DELETE PICKINGINFO failed (ispUnallocate_DynamicWaveAlloc_byWave)'
            GOTO RETURN_SP
         END
      
        DELETE PICKHEADER WITH (ROWLOCK) -- SOS# 178258
        WHERE PICKHEADERKey = @c_PickSlipNo
         IF @@ERROR <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 63013
            SELECT @c_errmsg = 'DELETE PICKHEADER failed (ispUnallocate_DynamicWaveAlloc_byWave)'
            GOTO RETURN_SP
         END        

         COMMIT TRAN
         FETCH NEXT FROM Cursor_PickSlip INTO @c_PickSlipNo
      END
      CLOSE Cursor_PickSlip 
      DEALLOCATE Cursor_PickSlip   
            

      -- 8. DELETE LOADPLAN -- Trigger DELETE LoadplanDetail, UPDATE Orders.LoadKey = ''

      DECLARE Cursor_LOADPLAN CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT LP.Loadkey
         FROM ORDERS OH WITH (NOLOCK)
         INNER  JOIN LOADPLAN LP WITH (NOLOCK) ON (OH.Loadkey = LP.Loadkey)
         WHERE  OH.UserDefine09 = @c_WaveKey
         AND   OH.Storerkey = @c_Storerkey  
         AND   isnull(OH.Loadkey,'') <> ''
         AND   @c_UnallocateWaveRetainLoad <> '1'   --WL01
      GROUP BY LP.Loadkey
      ORDER BY LP.Loadkey                                                  --(Wan01) Sort to delete
      OPEN Cursor_LOADPLAN 
         
      FETCH NEXT FROM Cursor_LOADPLAN INTO @c_Loadkey
      WHILE @@FETCH_STATUS <> -1
      BEGIN   
         BEGIN TRAN   

         -- DELETE LOADPLANDETAIL first -- (ChewKP01)
         DELETE LOADPLANDETAIL WITH (ROWLOCK) 
         WHERE  Loadkey = @c_Loadkey
         
         IF @@ERROR <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 63014
            SELECT @c_errmsg = 'DELETE LOADPLANDETAIL failed (ispUnallocate_DynamicWaveAlloc_byWave)'
            GOTO RETURN_SP
         END
         
            
         DELETE LOADPLAN WITH (ROWLOCK) -- SOS# 178258
         WHERE  Loadkey = @c_Loadkey

         IF @@ERROR <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 63014
            SELECT @c_errmsg = 'DELETE LOADPLAN failed (ispUnallocate_DynamicWaveAlloc_byWave)' -- (ChewKP01)
            GOTO RETURN_SP
         END
         
         COMMIT TRAN  
         

         FETCH NEXT FROM Cursor_LOADPLAN INTO @c_Loadkey
      END
      CLOSE Cursor_LOADPLAN 
      DEALLOCATE Cursor_LOADPLAN   


      /* ----------------------------------------------- */
      /* RETURN Result Set                               */
      /* ----------------------------------------------- */
      SELECT GroupType, SKU, QTY, LOC, ID, PickSlipNo, CartonNo, UCCNo, ReplenishmentGroup
      FROM @tTempRESULT

   END -- IF @n_continue = 1 OR @n_continue = 2

    WHILE @@TRANCOUNT<@n_starttcnt 
       BEGIN TRAN 
            
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispUnallocate_DynamicWaveAlloc_byWave'
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