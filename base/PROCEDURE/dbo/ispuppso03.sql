SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: ispUPPSO03                                         */  
/* Creation Date: 2020-06-04                                            */  
/* Copyright: IDS                                                       */  
/* Written by: Wan                                                      */  
/*                                                                      */  
/* Purpose: WMS-13120 - [PH] NIKE - WMS UnPacking Module                */  
/*          Storerconfig UnpickpackORD_SP={SPName} to enable UNpickpack */
/*          Process                                                     */
/*                                                                      */  
/* Called By: RCM Unpickpack Orders At Unpickpack Orders screen         */    
/*          : RCM Unpickpack By Load & Unpickpack By Wave               */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver  Purposes                                   */ 
/************************************************************************/   
CREATE PROCEDURE [dbo].[ispUPPSO03]  
      @c_OrderKey       NVARCHAR(10) 
   ,  @c_Loadkey        NVARCHAR(10)  
   ,  @c_ConsoOrderkey  NVARCHAR(30)  
   ,  @c_UPPLoc         NVARCHAR(10)
   ,  @c_UnpickMoveKey  NVARCHAR(10)   OUTPUT
   ,  @b_Success        INT            OUTPUT 
   ,  @n_Err            INT            OUTPUT 
   ,  @c_ErrMsg         NVARCHAR(250)  OUTPUT
   ,  @c_MBOLKey        NVARCHAR(10) = ''    
   ,  @c_WaveKey        NVARCHAR(10) = ''    
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_Continue              INT   = 1

         , @n_RowCount              INT   = 0

         , @c_Facility              NVARCHAR(5) = ''
         , @c_Storerkey             NVARCHAR(15)= ''
         , @c_orderkeys             NVARCHAR(4000)= ''
         
         , @n_CartonNo              INT
         , @c_PickSlipNo            NVARCHAR(10)= '' 
         , @c_Labelno               NVARCHAR(20)= '' 
         , @c_LabelLine             NVARCHAR(5)
              
         , @b_TaskAction            INT         = 0   --0:Do Nothing, 1:Delete, 2:Update and change wave(sharewave)
         , @b_delPick               INT         = 0

         , @c_PickDetailKey         NVARCHAR(10)= ''
         , @c_TaskDetailKey         NVARCHAR(10)= ''
         , @c_TaskDetailKey_CPK     NVARCHAR(10)= ''
         , @c_Taskdetailkey_ASTRPT  NVARCHAR(10)= ''
         , @c_ListKey               NVARCHAR(10)= ''
         , @c_ShareWavekey          NVARCHAR(10)= ''
         , @c_TaskStatus            NVARCHAR(10)= ''
         , @c_UCCNo                 NVARCHAR(20)= ''
         , @c_CaseID                NVARCHAR(20)= ''
         , @c_UOM                   NVARCHAR(10)= ''
         
         , @n_UCC_RowRef            INT         = 0

         , @b_DelGRpl               BIT = 0              --2020-07-16
         , @b_ByWave                BIT = 0              --2020-07-16
         , @c_Wavekey_Share         NVARCHAR(10) = ''    --2020-07-16

   DECLARE @CUR_ORD                 CURSOR
         , @CUR_PICK                CURSOR
         , @CUR_PACK                CURSOR
         , @CUR_UCC                 CURSOR
         , @CUR_TD                  CURSOR

         , @CUR_GRPL                CURSOR               --2020-07-16

   SET @n_err           = 0
   SET @b_success       = 1
   SET @c_errmsg        = ''


   IF OBJECT_ID('tempdb..#tERRORDER','U') IS NOT NULL
   BEGIN
      DROP TABLE #tERRORDER;
   END

   CREATE TABLE #tERRORDER 
      (  Orderkey    NVARCHAR(10) NOT NULL DEFAULT('')   PRIMARY KEY
      )

   IF OBJECT_ID('tempdb..#tORDER','U') IS NOT NULL
   BEGIN
      DROP TABLE #tORDER;
   END

   CREATE TABLE #tORDER 
      (  Orderkey    NVARCHAR(10) NOT NULL DEFAULT('')   PRIMARY KEY
      ,  Wavekey     NVARCHAR(10) NOT NULL DEFAULT('') 
      ,  Storerkey   NVARCHAR(15) NOT NULL DEFAULT('') 
      )

   IF @c_Orderkey <> ''
   BEGIN
      INSERT INTO #tORDER ( Orderkey, Wavekey, Storerkey )
      SELECT OH.Orderkey
            ,Wavekey = ISNULL(OH.UserDefine09,'')
            ,OH.Storerkey
      FROM ORDERS OH WITH (NOLOCK)
      WHERE OH.Orderkey = @c_Orderkey
      AND OH.[Status] < '9'
   END	
   ELSE IF @c_Loadkey <> ''
   BEGIN
      INSERT INTO #tORDER ( Orderkey, Wavekey, Storerkey )
      SELECT OH.Orderkey
            ,Wavekey = ISNULL(OH.UserDefine09,'')
            ,OH.Storerkey
      FROM ORDERS OH WITH (NOLOCK)
      WHERE OH.Loadkey = @c_Loadkey
      AND OH.[Status] < '9'
   END
   ELSE IF @c_Wavekey <> ''
   BEGIN
      SET @b_ByWave = 1
      INSERT INTO #tORDER ( Orderkey, Wavekey, Storerkey )
      SELECT OH.Orderkey
            ,WD.Wavekey
            ,OH.Storerkey
      FROM WAVEDETAIL WD WITH (NOLOCK) 
      JOIN ORDERS     OH WITH (NOLOCK) ON WD.Orderkey = OH.Orderkey
      WHERE WD.Wavekey = @c_Wavekey
      AND OH.[Status] < '9'
   END

   SET @n_RowCount = @@ROWCOUNT

   IF @n_RowCount = 0 
   BEGIN 
      SET @n_Continue = 3
      SET @n_Err = 87010
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': No Order to UnPickPack. (ispUPPSO03)'
      GOTO QUIT_SP
   END

   -- Check Pending RPF/ASTRPT Tasks
   IF @n_Continue IN (1,2)
   BEGIN
      INSERT INTO #tERRORDER (Orderkey)
      SELECT DISTINCT TORD.Orderkey
      FROM #tORDER TORD
      JOIN PICKDETAIL PD WITH (NOLOCK) ON TORD.Orderkey = PD.Orderkey
      JOIN TASKDETAIL TD WITH (NOLOCK) ON PD.DropID = TD.CaseID
      WHERE PD.DropID <> ''
      AND PD.[Status] < '9'
      AND PD.ShipFlag <> 'Y'
      AND TD.[Status] > '0'
      AND TD.[Status] < '9'
      AND TD.TaskType IN ('RPF','ASTRPT')
      AND PD.Wavekey = TD.Wavekey
      ORDER BY TORD.Orderkey
          
      IF @@ROWCOUNT > 0 
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 87020
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Pending RPF And ASTRPT Task found'
         GOTO GET_ERR_ORDERS      
      END

      -- Check not finish ASTRPT Tasks
      INSERT INTO #tERRORDER (Orderkey)
      SELECT DISTINCT TORD.Orderkey
      FROM #tORDER TORD
      JOIN PICKDETAIL PD WITH (NOLOCK) ON TORD.Orderkey = PD.Orderkey
      JOIN TASKDETAIL TD WITH (NOLOCK) ON PD.DropID = TD.CaseID
      WHERE PD.DropID   <> ''
      AND PD.[Status] < '9'
      AND PD.ShipFlag <> 'Y'
      AND TD.[Status] NOT IN ('9','X')
      AND TD.TaskType IN ('ASTRPT')
      ORDER BY TORD.Orderkey
          
      IF @@ROWCOUNT > 0 
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 87030
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': ASTRPT Task has not finished yet'
         GOTO GET_ERR_ORDERS      
      END

      -- Check Pending CPK Tasks
      INSERT INTO #tERRORDER (Orderkey)
      SELECT DISTINCT TORD.Orderkey
      FROM #tORDER TORD
      JOIN PICKDETAIL PD WITH (NOLOCK) ON TORD.Orderkey = PD.Orderkey
      JOIN TASKDETAIL TD WITH (NOLOCK) ON PD.CaseID = TD.CaseID
      WHERE PD.CaseID <> ''
      AND PD.[Status] < '9'
      AND PD.ShipFlag <> 'Y'
      AND TD.[Status] > '0'
      AND TD.[Status] < '9'
      AND TD.TaskType IN ('CPK')
      ORDER BY TORD.Orderkey
             
      IF @@ROWCOUNT > 0 
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 87040
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Pending CPK Task found'
         GOTO GET_ERR_ORDERS      
      END

      -- Order pack in Progress in Packing Station but not pack confirmed
      INSERT INTO #tERRORDER (Orderkey)
      SELECT DISTINCT TORD.Orderkey
      FROM #tORDER TORD
      JOIN PICKDETAIL PD WITH (NOLOCK) ON TORD.Orderkey = PD.Orderkey
      JOIN PACKHEADER PH WITH (NOLOCK) ON PD.Orderkey = PH.Orderkey
      JOIN LOC           WITH (NOLOCK) ON PD.Loc = LOC.Loc
      WHERE PD.[Status] < '9'
      AND PD.ShipFlag   <>'Y'
      AND PH.[Status]   < '9'
      AND LocationType NOT IN ('DYNPPICK', 'DYNPICKP', 'DPBULK', 'OTHER')
      AND LocationCategory NOT IN ('SHELVING', 'BULK')
      ORDER BY TORD.Orderkey
      
      IF @@ROWCOUNT > 0          
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 87050
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Pack has not completed yet'
         GOTO GET_ERR_ORDERS      
      END

      GET_ERR_ORDERS:

      IF @n_Continue = 3
      BEGIN 
         IF @c_Orderkey = ''
         BEGIN
            WHILE 1 = 1
            BEGIN
               SELECT TOP 1 @c_Orderkey = Orderkey
               FROM #tERRORDER
               WHERE Orderkey > @c_Orderkey
               ORDER BY Orderkey

               IF @c_Orderkey = '' OR @@ROWCOUNT = 0
               BEGIN
                  BREAK
               END

               SET @c_Orderkeys = @c_Orderkeys + @c_Orderkey + ','
            END
  
            IF @c_Orderkeys <> ''
            BEGIN
               SET @c_Orderkeys = SUBSTRING(@c_Orderkeys,1, LEN(@c_Orderkeys) - 1 )
               SET @c_ErrMsg = @c_ErrMsg + ' for orders: ' + @c_Orderkeys 
            END
         END
         SET @c_ErrMsg = @c_ErrMsg + '. (ispUPPSO03)'
         GOTO QUIT_SP
      END 
   END
                  
   SET @CUR_ORD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT TORD.Orderkey
         ,TORD.Wavekey
         ,TORD.Storerkey
   FROM #tORDER TORD
   ORDER BY TORD.Orderkey

   OPEN @CUR_ORD
   
   FETCH FROM @CUR_ORD INTO @c_OrderKey, @c_Wavekey, @c_Storerkey
   
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -----------------------------------------
      -- Unpack Order START
      -----------------------------------------
      SET @c_PickSlipNo = ''
      SELECT @c_PickSlipNo = PH.PickSlipNo
      FROM PACKHEADER PH WITH (NOLOCK)
      WHERE PH.Orderkey = @c_Orderkey

      IF @c_PickSlipNo <> ''
      BEGIN
         --Delete Packinfo
         SET @CUR_PACK = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PIF.CartonNo
         FROM PACKINFO PIF WITH (NOLOCK)
         WHERE PIF.PickSlipNo = @c_PickSlipNo
         ORDER BY PIF.CartonNo

         OPEN @CUR_PACK
   
         FETCH FROM @CUR_PACK INTO @n_CartonNo
   
         WHILE @@FETCH_STATUS = 0
         BEGIN
            DELETE PACKINFO  
            WHERE PickSlipNo= @c_PickSlipNo
            AND   CartonNo  = @n_CartonNo

            SET @n_Err = @@ERROR
            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               SET @c_ErrMsg = CONVERT(CHAR(250),@n_err)
               SET @n_Err = 87070
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Error Delete PACKINFO. (ispUPPSO03)'
                              + '( SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' )'
               GOTO QUIT_SP
            END
            FETCH FROM @CUR_PACK INTO @n_CartonNo
         END
         CLOSE @CUR_PACK
         DEALLOCATE @CUR_PACK

         SET @CUR_PACK = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PD.CartonNo
               ,PD.LabelNo
               ,PD.LabelLine
         FROM PACKDETAIL PD WITH (NOLOCK)
         WHERE PD.PickSlipNo = @c_PickSlipNo
         ORDER BY PD.CartonNo
               ,  PD.LabelLine

         OPEN @CUR_PACK

         FETCH FROM @CUR_PACK INTO @n_CartonNo, @c_LabelNo, @c_LabelLine
   
         WHILE @@FETCH_STATUS = 0
         BEGIN
            DELETE PACKDETAIL 
            WHERE PickSlipNo= @c_PickSlipNo
            AND   CartonNo  = @n_CartonNo
            AND   Labelno   = @c_Labelno
            AND   LabelLine = @c_LabelLine

            SET @n_Err = @@ERROR
            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               SET @c_ErrMsg = CONVERT(CHAR(250),@n_err)
               SET @n_Err = 87080
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Error Delete PACKDETAIL. (ispUPPSO03)'
                              + '( SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' )'
               GOTO QUIT_SP
            END
                
            FETCH FROM @CUR_PACK INTO @n_CartonNo, @c_LabelNo, @c_LabelLine
         END
         CLOSE @CUR_PACK
         DEALLOCATE @CUR_PACK

         IF EXISTS(  SELECT 1
                     FROM PACKHEADER PH WITH (NOLOCK)
                     WHERE PH.PickSlipNo = @c_PickSlipNo
                  )
         BEGIN
            DELETE PACKHEADER 
            WHERE PickSlipNo = @c_PickSlipNo

            SET @n_Err = @@ERROR
            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               SET @c_ErrMsg = CONVERT(CHAR(250),@n_err)
               SET @n_Err = 87090
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Error Delete PACKHEADER. (ispUPPSO03)'
                              + '( SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' )'
               GOTO QUIT_SP
            END
         END

         IF EXISTS(  SELECT 1
                     FROM PICKINGINFO PH WITH (NOLOCK)
                     WHERE PH.PickSlipNo = @c_PickSlipNo
                  )
         BEGIN
            DELETE PICKINGINFO 
            WHERE PickSlipNo = @c_PickSlipNo

            SET @n_Err = @@ERROR
            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               SET @c_ErrMsg = CONVERT(CHAR(250),@n_err)
               SET @n_Err = 87100
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Error Delete PICKINGINFO. (ispUPPSO03)'
                              + '( SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' )'
               GOTO QUIT_SP
            END
         END
      END
      -----------------------------------------
      -- Unpack Order END
      -----------------------------------------
      -----------------------------------------
      -- UnAllocate Order START
      -----------------------------------------
      SET @CUR_PICK = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PD.PickdetailKey
            ,CaseID        = ISNULL(PD.CaseID,'')
            ,UCCNo         = ISNULL(PD.DropID,'')
            ,TaskDetailKey = ISNULL(PD.TaskDetailKey,'')
            ,PD.UOM
      FROM #tORDER TORD
      JOIN PICKDETAIL PD WITH (NOLOCK) ON TORD.Orderkey = PD.Orderkey
      WHERE PD.Orderkey = @c_Orderkey 
      AND PD.[Status] < '9'
      AND PD.ShipFlag <> 'Y'
      ORDER BY TORD.Orderkey

      OPEN @CUR_PICK
   
      FETCH FROM @CUR_PICK INTO @c_PickDetailKey, @c_CaseID, @c_UCCNo, @c_TaskDetailKey, @c_UOM
   
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Delete CPK Tasks
         IF @c_CaseID <> ''
         BEGIN
            SET @CUR_TD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT TD.TaskDetailKey
            FROM TASKDETAIL TD WITH (NOLOCK) 
            WHERE TD.Storerkey = @c_Storerkey
            AND   TD.CaseID    = @c_CaseID 
            AND   TD.TaskType  = 'CPK'
            AND   TD.SourceType= 'ispRLWAV20-CPK'
            AND   TD.Wavekey = @c_Wavekey
            AND   TD.Orderkey= @c_Orderkey
            AND   TD.[Status] NOT IN ('9', 'X')
            ORDER BY TD.TaskDetailKey

            OPEN @CUR_TD
   
            FETCH FROM @CUR_TD INTO @c_TaskDetailKey_CPK
   
            WHILE @@FETCH_STATUS = 0
            BEGIN
               DELETE TASKDETAIL
               WHERE TaskdetailKey = @c_TaskDetailKey_CPK

               SET @n_Err = @@ERROR
               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3
                  SET @c_ErrMsg = CONVERT(CHAR(250),@n_err)
                  SET @n_Err = 87110
                  SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Error DELETE CPK TASKDETAIL. (ispUPPSO03)'
                                 + '( SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' )'
                  GOTO QUIT_SP
               END
               
               FETCH FROM @CUR_TD INTO @c_TaskDetailKey_CPK
            END
            CLOSE @CUR_TD
            DEALLOCATE @CUR_TD
         END

         -- Delete RPF & ASTRPT Tasks
         SET @c_ShareWavekey= ''
         IF @c_UCCNo <> '' 
         BEGIN
            SET @b_TaskAction   = 0
            SET @c_ShareWavekey= ''
            IF @c_TaskDetailkey <> ''
            BEGIN
               SET @c_TaskStatus = ''
               -- Get and check the PICKDETEAIL.Taskdetailkey OWN belong to same wave in Taskdetail
               SELECT TOP 1 
                      @c_TaskStatus  = TD.[Status]
                     ,@c_ShareWavekey= CASE WHEN TD.Wavekey = @c_Wavekey THEN '' ELSE TD.Wavekey END
               FROM TASKDETAIL TD WITH (NOLOCK) 
               WHERE TD.Storerkey = @c_Storerkey
               AND   TD.TaskDetailkey = @c_TaskDetailkey
               AND   TD.CaseID   = @c_UCCNo
               AND   TD.TaskType = 'RPF'
               AND   TD.SourceType IN ('ispRLWAV20-INLINE', 'ispRLWAV20-DTC', 'ispRLWAV20-REPLEN')
               AND   TD.[Status] NOT IN ('X')
               ORDER BY TD.[Status]
            
               IF @c_UOM IN ('2')  -- UCC Allocate for same orderkey and repl to Pack Station 
               BEGIN
                  SET @b_TaskAction = 1
               END

               IF @c_UOM IN ('6', '7')
               BEGIN
                  -- UCCNO Not Share same orderkey in same wavekey 
                  IF NOT EXISTS (SELECT 1
                                       FROM PICKDETAIL PD WITH (NOLOCK)
                                       WHERE PD.Storerkey = @c_Storerkey
                                       AND PD.DropID      = @c_UCCNo
                                       AND PD.Orderkey <> @c_Orderkey
                                       AND PD.Wavekey  = @c_Wavekey
                                       AND PD.ShipFlag <> 'Y'
                                       AND PD.[Status] < '9'
                                       )
                  BEGIN
                     SET @b_TaskAction = 1   -- Delete task 
                  END

                  IF @b_TaskAction = 1 AND @c_UOM = '7'
                  BEGIN
                     IF @c_ShareWavekey <> ''  -- IF the PICKDETAIL.Taskdetailkey/UCC is below to other wave in taskdetail, not to delete
                     BEGIN
                        SET @b_TaskAction = 0   -- do nothing
                     END
                     ELSE
                     BEGIN
                        -- Check
                        SELECT TOP 1 @c_ShareWavekey = PD.Wavekey
                        FROM PICKDETAIL      PD WITH (NOLOCK)
                        LEFT JOIN TASKDETAIL TD WITH (NOLOCK) ON PD.Storerkey = TD.Storerkey
                                                             AND PD.Wavekey = TD.Wavekey
                                                             AND TD.TaskType= 'RPF'
                        WHERE PD.Storerkey = @c_Storerkey
                        AND PD.DropID      = @c_UCCNo
                        AND PD.TaskDetailKey= @c_TaskDetailKey
                        AND PD.Wavekey  <> @c_Wavekey
                        AND PD.ShipFlag <> 'Y'
                        AND PD.[Status] < '9'
                        AND TD.TaskDetailKey IS NOT NULL

                        IF @c_ShareWavekey <> ''
                        BEGIN 
                           SET @b_TaskAction = 2 -- update to change wavekey
                        END
                     END
                  END
               END
            END

            IF @b_TaskAction IN (1,2)
            BEGIN
               IF @c_TaskStatus = '0'  -- Update RPF Task
               BEGIN
                  IF @b_TaskAction = 1
                  BEGIN
                     DELETE TASKDETAIL
                     WHERE TaskdetailKey = @c_TaskDetailKey

                     SET @n_Err = @@ERROR
                     IF @@ERROR <> 0
                     BEGIN
                        SET @n_Continue = 3
                        SET @c_ErrMsg = CONVERT(CHAR(250),@n_err)
                        SET @n_Err = 87120
                        SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Error DELETE RPF TASKDETAIL. (ispUPPSO03)'
                                       + '( SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' )'
                        GOTO QUIT_SP
                     END
                  END
                  ELSE
                  BEGIN -- TaskAction = 2
                     --- Change Taskdetail.Wavekey
                     UPDATE TASKDETAIL
                        SET Wavekey = @c_ShareWavekey
                          , TrafficCop= NULL
   	                    , EditDate  = GETDATE() 
   	                    , EditWho   = SUSER_SNAME() 
                     WHERE TaskdetailKey = @c_TaskDetailKey

                     SET @n_Err = @@ERROR
                     IF @@ERROR <> 0
                     BEGIN
                        SET @n_Continue = 3
                        SET @c_ErrMsg = CONVERT(CHAR(250),@n_err)
                        SET @n_Err = 87130
                        SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Error DELETE RPF TASKDETAIL. (ispUPPSO03)'
                                       + '( SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' )'
                        GOTO QUIT_SP
                     END
                  END
               END   -- RPF taskstatus in '0'
            END -- @b_TaskAction = 1
         END -- @c_UCCNo <> ''

         SET @b_delPick = 1
         IF @c_CaseID <> ''
         BEGIN
            SELECT TOP 1 @b_delPick = 0
            FROM TASKDETAIL TD WITH (NOLOCK) 
            WHERE TD.Storerkey = @c_Storerkey
            AND   TD.CaseID    = @c_CaseID 
            AND   TD.TaskType  = 'CPK'
            AND   TD.SourceType= 'ispRLWAV20-CPK'
            AND   TD.Wavekey = @c_Wavekey
            AND   TD.Orderkey= @c_Orderkey
            AND   TD.[Status] NOT IN ('9', 'X')
         END

         IF @b_delPick = 1 AND @c_UCCNo <> '' 
         BEGIN
            SELECT TOP 1 @b_delPick = 0
            FROM TASKDETAIL TD WITH (NOLOCK) 
            WHERE TD.Storerkey = @c_Storerkey
            AND   TD.CaseID    = @c_UCCNo 
            AND   TD.Wavekey   = @c_Wavekey
            AND   TD.TaskType  = 'RPF'
            AND   TD.SourceType IN ('ispRLWAV20-INLINE', 'ispRLWAV20-DTC', 'ispRLWAV20-REPLEN')
            AND   TD.[Status] NOT IN ('9','X')
         END

         IF @b_delPick = 1
         BEGIN
            DELETE PICKDETAIL                         -- Unallocate pickdetail will unallocate UCC
            WHERE PickdetailKey = @c_PickdetailKey

            SET @n_Err = @@ERROR
            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               SET @c_ErrMsg = CONVERT(CHAR(250),@n_err)
               SET @n_Err = 87140
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Error DELETE PICKDETAIL. (ispUPPSO03)'
                              + '( SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' )'
               GOTO QUIT_SP
            END
         END

         FETCH FROM @CUR_PICK INTO @c_PickDetailKey, @c_CaseID, @c_UCCNo, @c_TaskDetailKey, @c_UOM
      END
      CLOSE @CUR_PICK
      DEALLOCATE @CUR_PICK
      -----------------------------------------
      -- UnAllocate Order END
      -----------------------------------------
      FETCH FROM @CUR_ORD INTO @c_OrderKey, @c_Wavekey, @c_Storerkey
   END
   CLOSE @CUR_ORD
   DEALLOCATE @CUR_ORD

   --2020-07-16 - START 
   IF @b_ByWave = 1
   BEGIN
      SET @CUR_GRPL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT TD.TaskDetailKey
      FROM TASKDETAIL TD WITH (NOLOCK)
      WHERE TD.Wavekey = @c_Wavekey
      AND   TD.Tasktype IN ( 'RPF', 'CPK')                                             
      AND   TD.[Status] NOT IN ('X', '9')                                                   
      AND   TD.SourceType IN ( 'ispRLWAV20-REPLEN' )  
      AND   TD.TaskDetailKey <> ''
      AND   TD.UOM = '7'

      OPEN @CUR_GRPL

      FETCH NEXT FROM @CUR_GRPL INTO  @c_TaskDetailKey

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @b_DelGRpl = 1

         -- Check if other wave that share the same taskdetailkey had released wave
         SET @c_Wavekey_Share = ''
         SELECT TOP 1
               @c_Wavekey_Share = PD.Wavekey
         FROM PICKDETAIL PD WITH (NOLOCK) 
         JOIN LOC L WITH (NOLOCK) ON PD.Loc = L.Loc
         LEFT JOIN TASKDETAIL TD WITH (NOLOCK)
                              ON  TD.Storerkey = PD.Storerkey
                              AND TD.Wavekey   = PD.Wavekey
                              AND TD.TaskType  = 'RPF'
         WHERE PD.TaskDetailKey = @c_TaskDetailkey
         AND PD.Wavekey <> @c_Wavekey
         AND PD.[Status] < '3'
         AND L.LocationType NOT IN ( 'DYNPPICK', 'DYNPICKP' )
         AND TD.TaskDetailKey IS NOT NULL
         ORDER BY TD.PickDetailKey
            
         IF @c_Wavekey_Share <> ''
         BEGIN
            SET @b_DelGRpl = 0
         END
   
         IF @b_DelGRpl = 1
         BEGIN
            DELETE TASKDETAIL WITH (ROWLOCK)
            WHERE TaskDetailkey = @c_TaskDetailkey

            SET @n_err = @@ERROR
            IF @n_err <> 0 
            BEGIN
               SET @n_continue = 3
               SET @n_err = 87150
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': DELETE Taskdetail Table Failed. (ispUPPSO03)' 
               GOTO QUIT_SP
            END
         END
         ELSE
         BEGIN
            ----------------------------------------------------
            -- Change the Task to Share Wave instead of deleting
            ----------------------------------------------------
            UPDATE TASKDETAIL 
               SET Wavekey = @c_Wavekey_Share
                  ,Trafficcop = NULL
                  ,EditDate = GETDATE()
                  ,EditWho  = SUSER_SNAME()
            WHERE TaskDetailkey = @c_TaskDetailkey

            SET @n_err = @@ERROR
            IF @n_err <> 0 
            BEGIN
               SET @n_continue = 3
               SET @n_err = 87160
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE Taskdetail Table Failed. (ispUPPSO03)' 
               GOTO QUIT_SP
            END
         END    
         FETCH NEXT FROM @CUR_GRPL INTO @c_TaskDetailKey
      END
      CLOSE @CUR_GRPL
      DEALLOCATE @CUR_GRPL
      --2020-07-16 - END
   END

   QUIT_SP:

   IF @n_Continue = 3
   BEGIN
       SET @b_success = 0
       EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispUPPSO03'  
   END   
END  

GO