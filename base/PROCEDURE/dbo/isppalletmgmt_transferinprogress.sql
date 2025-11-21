SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: ispPalletMgmt_TransferInProgress                            */
/* Creation Date: 20-AP-2021                                            */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-16767 Pallet Management transfer in progress (status 3) */
/*                                                                      */
/* Called By: n_cst_palletmgmt.Event ue_transferinprogress              */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2022-01-24  Wan01    1.1   LFWM-3158 - TH-SCE All Account - Pallet   */
/*                            Management - Transfer                     */
/* 2022-01-24  Wan01    1.1   DevOps Combine Script                     */
/************************************************************************/
CREATE PROC [dbo].[ispPalletMgmt_TransferInProgress] 
            @c_PMkey             NVARCHAR(10) 
         ,  @b_Success           INT = 0  OUTPUT 
         ,  @n_err               INT = 0  OUTPUT 
         ,  @c_errmsg            NVARCHAR(215) = '' OUTPUT
         ,  @c_SourceApp         NVARCHAR(10)  = '' --Default Blank = 'Exceed', SCE - 'WM'
         ,  @c_StorerRestrict    NVARCHAR(250) = '' --Default Blank if from Exceed, SCE will pass restrict storers list   
         ,  @c_FacilityRestrict  NVARCHAR(250) = '' --Default Blank if from Exceed, SCE will pass restrict facilities list 
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt          INT
         , @n_Continue           INT 
         , @c_SQL                NVARCHAR(4000)
         , @c_PMValidationRules  NVARCHAR(30)    
         , @c_PMLineNumber       NVARCHAR(5)
         , @c_FromStorerkey      NVARCHAR(15) 
         , @c_ToStorerkey        NVARCHAR(15)
         , @c_Storerkey          NVARCHAR(15) 
         , @c_TranType           NVARCHAR(10)
         , @c_Country            NVARCHAR(30)
         , @c_username           NVARCHAR(128)  
         --, @c_StorerRestrict     NVARCHAR(250)               --(Wan01)     
         --, @c_FacilityRestrict   NVARCHAR(250)               --(Wan01) 

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''
   
   SELECT @c_Country = NSQLValue 
   FROM NSQLCONFIG (NOLOCK) 
   WHERE ConfigKey = 'COUNTRY'
     
   IF EXISTS ( SELECT 1
               FROM PALLETMGMT WITH (NOLOCK)
               WHERE PMKey = @c_PMkey 
               AND ( RTRIM(Facility) = '' OR Facility IS NULL )
              ) 
   BEGIN
      SET @n_continue = 3    
      SET @n_err = 81010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
      SET @c_errmsg= 'Facility is required. (ispPalletMgmt_TransferInProgress)' 
      GOTO QUIT_SP
   END

   IF EXISTS ( SELECT 1
               FROM PALLETMGMTDETAIL WITH (NOLOCK)
               WHERE PMKey = @c_PMkey 
               AND ( RTRIM(FromStorerkey) = '' OR FromStorerkey IS NULL )
               AND ( RTRIM(ToStorerkey) = '' OR ToStorerkey IS NULL )
              ) 
   BEGIN
      SET @n_continue = 3    
      SET @n_err = 81020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
      SET @c_errmsg= 'Both From Storer & To Storer are blank. (ispPalletMgmt_TransferInProgress)' 
      GOTO QUIT_SP
   END

   IF EXISTS ( SELECT 1
               FROM PALLETMGMTDETAIL WITH (NOLOCK)
               WHERE PMKey = @c_PMkey 
               AND ( RTRIM(PMAccountNo) = '' OR PMAccountNo IS NULL )
              ) 
   BEGIN
      SET @n_continue = 3    
      SET @n_err = 81030   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
      SET @c_errmsg= 'PM Account # is required. (ispPalletMgmt_TransferInProgress)' 
      GOTO QUIT_SP
   END

   IF EXISTS ( SELECT 1
               FROM PALLETMGMTDETAIL WITH (NOLOCK)
               WHERE PMKey = @c_PMkey 
               AND ( RTRIM(Type) = '' OR Type IS NULL )
              ) 
   BEGIN
      SET @n_continue = 3    
      SET @n_err = 81040  -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
      SET @c_errmsg= 'PM Transaction Type is required. (ispPalletMgmt_TransferInProgress)' 
      GOTO QUIT_SP
   END

   IF EXISTS ( SELECT 1
               FROM PALLETMGMTDETAIL WITH (NOLOCK)
               WHERE PMKey = @c_PMkey
               AND ( RTRIM(PalletType) = '' OR PalletType IS NULL )
              ) 
   BEGIN
      SET @n_continue = 3    
      SET @n_err = 81050   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
      SET @c_errmsg= 'Pallet Type is required. (ispPalletMgmt_TransferInProgress)' 
      GOTO QUIT_SP
   END

   IF EXISTS ( SELECT 1
               FROM PALLETMGMTDETAIL WITH (NOLOCK)
               WHERE PMKey = @c_PMkey 
               AND Type <> 'TRF'
               ) 
   BEGIN
      SET @n_continue = 3    
      SET @n_err = 81060   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
      SET @c_errmsg= 'Only Transfer Type is allowed for Transfer In Progress. (ispPalletMgmt_TransferInProgress)' 
      GOTO QUIT_SP
   END

   IF NOT EXISTS ( SELECT 1
                   FROM PALLETMGMTDETAIL WITH (NOLOCK)
                   WHERE PMKey = @c_PMkey 
                   AND Type = 'TRF'
               ) 
   BEGIN
      SET @n_continue = 3    
      SET @n_err = 81070   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
      SET @c_errmsg= 'No transfer type found. (ispPalletMgmt_TransferInProgress)' 
      GOTO QUIT_SP
   END

   IF EXISTS ( SELECT 1
               FROM PALLETMGMTDETAIL WITH (NOLOCK)
               WHERE PMKey = @c_PMkey 
               AND Type = 'TRF'
               AND Status < '9'
               AND ( RTRIM(FromStorerkey) = '' OR FromStorerkey IS NULL OR
                     RTRIM(ToStorerkey) = '' OR ToStorerkey IS NULL )
               ) 
   BEGIN
      SET @n_continue = 3    
      SET @n_err = 81080   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
      SET @c_errmsg= 'Empty From/To Storer found for transfer transaction type. (ispPalletMgmt_TransferInProgress)' 
      GOTO QUIT_SP
   END

   IF @c_Country = 'TH'
   BEGIN
        IF EXISTS (SELECT 1 
                 FROM PALLETMGMT       PMH WITH (NOLOCK)
                 JOIN PALLETMGMTDETAIL PMD WITH (NOLOCK) ON (PMH.PMKey = PMD.PMkey)
                 WHERE PMH.PMKey = @c_PMkey 
                 GROUP BY PMD.DocketNo
                 HAVING COUNT(1) > 1
                 UNION ALL
                 SELECT 1
                 FROM PALLETMGMT       PMH WITH (NOLOCK)
                 JOIN PALLETMGMTDETAIL PMD WITH (NOLOCK) ON (PMH.PMKey = PMD.PMkey)
                 WHERE PMH.PMKey = @c_PMkey
                 AND EXISTS(SELECT 1 
                            FROM PALLETMGMTDETAIL PMD2 (NOLOCK) 
                            WHERE PMD2.PMKey <> PMH.PMKey 
                            AND PMD2.Docketno = PMD.Docketno)                           
                 )
      BEGIN
         SET @n_continue = 3    
         SET @n_err = 81090   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SET @c_errmsg= 'Found Duplicate DocketNo. (ispPalletMgmt_TransferInProgress)' 
         GOTO QUIT_SP         
      END                  

        IF EXISTS (SELECT 1 
                 FROM PALLETMGMT       PMH WITH (NOLOCK)
                 JOIN PALLETMGMTDETAIL PMD WITH (NOLOCK) ON (PMH.PMKey = PMD.PMkey)
                 WHERE PMH.PMKey = @c_PMkey 
                 AND PMD.Status < '9'
                 AND PMD.Type = 'TRF'
                 AND (ISNULL(PMD.Userdefine03,'') = '' 
                      OR ISNULL(PMD.Userdefine04,'') = ''))
      BEGIN
         SET @n_continue = 3    
         SET @n_err = 81100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SET @c_errmsg= 'Userdefine03 or Userdefine04 Cannot be empty. (ispPalletMgmt_TransferInProgress)' 
         GOTO QUIT_SP         
      END    
      
      --(Wan01) - START
      IF @c_SourceApp = ''             --If from Exceed
      BEGIN    
         SET ANSI_NULLS ON
         SET ANSI_WARNINGS ON
            
         SET @c_username = SUSER_SNAME()

         EXEC isp_GetUserRestriction
            @c_username = @c_username  
           ,@c_StorerRestrict = @c_StorerRestrict OUTPUT  
           ,@c_FacilityRestrict = @c_FacilityRestrict OUTPUT  
           ,@b_Success = @b_Success OUTPUT    
           ,@n_Err = @n_Err OUTPUT    
           ,@c_ErrMsg = @c_ErrMsg OUTPUT        
                        
         SET ANSI_NULLS OFF
         SET ANSI_WARNINGS OFF
      END
      --(Wan01) - END
      
      SET @c_FromStorerkey = ''
      SELECT TOP 1 @c_FromStorerkey = PMD.FromStorerkey
      FROM PALLETMGMT       PMH WITH (NOLOCK)
      JOIN PALLETMGMTDETAIL PMD WITH (NOLOCK) ON (PMH.PMKey = PMD.PMkey)
      WHERE PMH.PMKey = @c_PMkey 
      AND PMD.Status < '9'
      AND PMD.FromStorerkey NOT IN (SELECT RTRIM(LTRIM(fds.Colvalue)) FROM dbo.fnc_DelimSplit(',',@c_StorerRestrict) AS fds)                 

      IF ISNULL(@c_FromStorerkey,'') <> ''
      BEGIN      
         SET @n_continue = 3    
         SET @n_err = 81110   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SET @c_errmsg= 'Current user ' + RTRIM(@c_username) + ' is not allowed to access from storer: ' + RTRIM(@c_FromStorerkey) + ' (ispPalletMgmt_TransferInProgress)' 
         GOTO QUIT_SP
      END
   END

   CREATE TABLE #TMP_PM
      (  Facility       NVARCHAR(5)    NULL
      ,  FromStorerkey  NVARCHAR(15)   NULL
      ,  PMAccountNo    NVARCHAR(30)   NULL
      ,  PalletType     NVARCHAR(30)   NULL
      ,  Qty            INT            NULL 
      ) 

   INSERT INTO #TMP_PM
      (  Facility         
      ,  FromStorerkey  
      ,  PMAccountNo    
      ,  PalletType      
      ,  Qty             
      ) 
   SELECT PMH.Facility
         ,PMD.FromStorerkey
         ,PMD.PMAccountNo
         ,PMD.PalletType
         ,ISNULL(SUM(PMD.Qty),0) + ISNULL(TRF3.Qty,0) 
   FROM PALLETMGMT       PMH WITH (NOLOCK)
   JOIN PALLETMGMTDETAIL PMD WITH (NOLOCK) ON (PMH.PMKey = PMD.PMkey)
   OUTER APPLY (SELECT SUM(Qty) AS Qty 
                FROM PALLETMGMT PMH2 (NOLOCK) 
                JOIN PALLETMGMTDETAIL PMD2 (NOLOCK) ON PMH2.PMKey = PMD2.PMKey 
                WHERE PMH2.Facility = PMH.Facility
                AND PMD2.FromStorerkey = PMD.FromStorerkey
                AND PMD2.PMAccountNo = PMD.PMAccountNo
                AND PMD2.PalletType = PMD.PalletType
                AND PMH2.PMKey <> PMH.PMKey
                AND PMD2.Type ='TRF'
                AND PMD2.Status = '3') AS TRF3
   WHERE  PMH.PMKey = @c_PMkey 
   AND PMD.Type IN ('WD', 'TRF')
   AND PMD.Status < '9'
   GROUP BY  PMH.Facility
            ,PMD.FromStorerkey
            ,PMD.PMAccountNo
            ,PMD.PalletType
            ,TRF3.Qty

   IF EXISTS ( SELECT 1
               FROM #TMP_PM TMP WITH (NOLOCK)
               LEFT JOIN PMINV   INV WITH (NOLOCK) ON (TMP.Facility = INV.Facility)
                                                   AND(TMP.FromStorerkey = INV.Storerkey)
                                                   AND(TMP.PMAccountNo = INV.AccountNo)
                                                   AND(TMP.PalletType = INV.PalletType)
               WHERE TMP.Qty > ISNULL(INV.Qty,0)               
             ) 
   BEGIN
      SET @n_continue = 3    
      SET @n_err = 81120   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
      SET @c_errmsg= 'Pallet Management total withdrawal qty > Pallet inventory Qty found. (ispPalletMgmt_TransferInProgress)' 
      GOTO QUIT_SP
   END

   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      DECLARE CUR_PMDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PMLineNumber
            ,FromStorerkey
            ,ToStorerkey
            ,Type
      FROM   PALLETMGMTDETAIL WITH (NOLOCK)
      WHERE  PMKey = @c_PMkey 
      AND    Status < '9'

      OPEN CUR_PMDET

      FETCH NEXT FROM CUR_PMDET INTO @c_PMLineNumber
                                    ,@c_FromStorerkey
                                    ,@c_ToStorerkey
                                    ,@c_TranType

      WHILE @@FETCH_STATUS <> -1 AND (@n_Continue = 1 OR @n_Continue = 2)
      BEGIN
         SET @c_Storerkey = CASE WHEN @c_TranType = 'DP' THEN @c_ToStorerkey ELSE @c_FromStorerkey END

         SELECT @c_PMValidationRules = SC.sValue
         FROM STORERCONFIG SC (NOLOCK)
         JOIN CODELKUP CL (NOLOCK) ON (SC.sValue = CL.Listname)
         WHERE SC.StorerKey = @c_StorerKey
         AND SC.Configkey = 'PMExtendedValidation'

         IF ISNULL(@c_PMValidationRules,'') <> ''
         BEGIN
            EXEC isp_PM_ExtendedValidation @c_PMkey = @c_PMkey 
                                          ,@c_PMLineNumber = @c_PMLineNumber
                                          ,@c_PMValidationRules = @c_PMValidationRules 
                                          ,@b_Success= @b_Success OUTPUT
                                          ,@c_ErrMsg = @c_ErrMsg OUTPUT
            IF @b_Success <> 1
            BEGIN
               SET @n_Continue = 3
               SET @n_err = 81130
               GOTO QUIT_SP
            END
         END
         ELSE   
         BEGIN  
            SELECT @c_PMValidationRules = SC.sValue    
            FROM STORERCONFIG SC (NOLOCK) 
            WHERE SC.StorerKey = @c_StorerKey 
            AND SC.Configkey = 'PMExtendedValidation'    
            
            IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_PMValidationRules) AND type = 'P')          
            BEGIN          
               SET @c_SQL = 'EXEC ' + @c_PMValidationRules 
                          + ' @c_PMkey '
                          + ',@c_PMLineNumber '
                          + ',@b_Success OUTPUT '
                          + ',@n_Err     OUTPUT '
                          + ',@c_ErrMsg  OUTPUT '          

               EXEC sp_executesql @c_SQL,          
                    N'@c_PMkey NVARCHAR(10), @b_Success Int OUTPUT, @n_Err Int OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT'
                   , @c_PMkey  
                   , @c_PMLineNumber        
                   , @b_Success  OUTPUT          
                   , @n_Err      OUTPUT          
                   , @c_ErrMsg   OUTPUT 
       
               IF @b_Success <> 1     
               BEGIN    
                  SET @n_Continue = 3    
                  SET @n_err=81110    
                  GOTO QUIT_SP
               END         
            END  
         END   
         
         UPDATE PALLETMGMTDETAIL WITH (ROWLOCK)
         SET Userdefine10 = CASE WHEN @c_Country = 'TH' THEN CAST(Qty AS NVARCHAR) ELSE Userdefine10 END
               ,Status = '3'
               ,TrafficCop = NULL
               ,EditWho  = SUSER_NAME()
               ,EditDate = GETDATE()
         WHERE  PMKey = @c_PMkey 
         AND    PMLineNumber = @c_PMLineNumber
         AND    Status < '9'

         SET @n_err = @@ERROR
         IF @n_err <> 0     
         BEGIN  
            SET @n_continue = 3    
            SET @n_err = 81140   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE PALLETMGMTDETAIL Failed. (ispPalletMgmt_TransferInProgress)' 
                         + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
            GOTO QUIT_SP
         END

         FETCH NEXT FROM CUR_PMDET INTO @c_PMLineNumber
                                       ,@c_FromStorerkey
                                       ,@c_ToStorerkey
                                       ,@c_TranType
      END -- While 
      CLOSE CUR_PMDET
      DEALLOCATE CUR_PMDET
   END 

   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      UPDATE PALLETMGMT WITH (ROWLOCK)
      SET Status = '3'
         ,SourceType = CASE WHEN @c_Country = 'TH' THEN 'WHTransfer' ELSE SourceType END    
         ,TrafficCop = NULL
         ,EditWho  = SUSER_NAME()
         ,EditDate = GETDATE()
      WHERE PMKey = @c_PMkey
      AND Status < '9'
         
      SET @n_err = @@ERROR
      IF @n_err <> 0     
      BEGIN  
         SET @n_continue = 3    
         SET @n_err = 81150   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE PALLETMGMT Failed. (ispPalletMgmt_TransferInProgress)' 
                      + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         GOTO QUIT_SP
      END
   END
   
QUIT_SP:

   IF CURSOR_STATUS( 'LOCAL', 'CUR_PMDET') in (0 , 1)  
   BEGIN
      CLOSE CUR_PMDET
      DEALLOCATE CUR_PMDET
   END

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_Success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTCnt
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispPalletMgmt_TransferInProgress'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END   
END -- procedure

GO