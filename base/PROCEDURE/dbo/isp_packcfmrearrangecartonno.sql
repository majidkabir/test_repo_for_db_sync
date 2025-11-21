SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_PackCfmRearrangeCartonNo                       */  
/* Creation Date: 09-Sep-2020                                           */  
/* Copyright: LFL                                                       */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose:  WMS-15016 - Rearrange Carton Number upon Pack Confirm      */
/*                                                                      */  
/* Called By: ntrPackHeaderUpdate                                       */    
/*                                                                      */  
/* GitLab Version: 1.0                                                  */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/************************************************************************/  

CREATE PROCEDURE [dbo].[isp_PackCfmRearrangeCartonNo]  
      @c_Pickslipno     NVARCHAR(10) 
   ,  @b_Success        INT           OUTPUT 
   ,  @n_Err            INT           OUTPUT 
   ,  @c_ErrMsg         NVARCHAR(250) OUTPUT
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @n_Continue            INT
         , @n_StartTCnt           INT
         , @c_GetPickslipno       NVARCHAR(10)
         , @c_GetCartonNo         INT
         , @c_GetActualCartonNo   INT

   SET @n_err        = 0
   SET @b_success    = 1
   SET @c_errmsg     = ''

   SET @n_Continue   = 1
   SET @n_StartTCnt  = @@TRANCOUNT
   
   CREATE TABLE #TMP_Packdetail (
      Pickslipno       NVARCHAR(10),
      CartonNo         INT,
      ActualCartonNo   INT	
   )
   
   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      INSERT INTO #TMP_Packdetail (Pickslipno, CartonNo, ActualCartonNo)
      SELECT PD.Pickslipno, PD.CartonNo, Row_Number() OVER (PARTITION BY PD.Pickslipno ORDER BY PD.Pickslipno, PD.CartonNo ASC) AS ActualCartonNo
      FROM PACKDETAIL PD (NOLOCK)
      WHERE PD.Pickslipno = @c_Pickslipno
      GROUP BY PD.Pickslipno, PD.CartonNo
      ORDER BY PD.CartonNo ASC
   
      IF EXISTS (SELECT 1 FROM #TMP_Packdetail WHERE CartonNo <> ActualCartonNo)
      BEGIN
      	DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   	   SELECT Pickslipno, CartonNo, ActualCartonNo
         FROM #TMP_Packdetail
         
         OPEN CUR_LOOP
         	
         FETCH NEXT FROM CUR_LOOP INTO @c_GetPickslipno, @c_GetCartonNo, @c_GetActualCartonNo
         
         WHILE @@FETCH_STATUS <> -1
         BEGIN
         	UPDATE PACKDETAIL WITH (ROWLOCK)
         	SET CartonNo   = @c_GetActualCartonNo, 
         	    ArchiveCop = NULL,
         	    EditDate   = GETDATE(),
         	    EditWho    = SUSER_SNAME()
         	WHERE PickSlipNo = @c_GetPickslipno AND CartonNo = @c_GetCartonNo
         	
         	SELECT @n_err = @@ERROR
         	
         	IF @n_err <> 0  
         	BEGIN  
         	   SET @n_continue = 3  
         	   SET @n_err = 82900   
         	   SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Updating Packdetail Table. (isp_PackCfmRearrangeCartonNo)'   
         	                + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '    
         	END
         	
         	--Rearrange Packinfo
         	IF EXISTS (SELECT 1 FROM PACKINFO (NOLOCK) WHERE PickSlipNo = @c_GetPickslipno AND CartonNo = @c_GetCartonNo)
         	BEGIN
         	   UPDATE PACKINFO WITH (ROWLOCK)
         	   SET CartonNo   = @c_GetActualCartonNo, 
         	       TrafficCop = NULL,
         	       EditDate   = GETDATE(),
         	       EditWho    = SUSER_SNAME()
         	   WHERE PickSlipNo = @c_GetPickslipno AND CartonNo = @c_GetCartonNo
         	
         	   IF @n_err <> 0  
         	   BEGIN  
         	      SET @n_continue = 3  
         	      SET @n_err = 82905   
         	      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Updating PACKINFO Table. (isp_PackCfmRearrangeCartonNo)'   
         	                   + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '    
         	   END
         	END
         	
            FETCH NEXT FROM CUR_LOOP INTO @c_GetPickslipno, @c_GetCartonNo, @c_GetActualCartonNo
         END   --CURSOR
      END   --IF EXISTS
   END   --@n_Continue = 1 OR @n_Continue = 2

QUIT_SP:
   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN (0 , 1)
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP   
   END

   IF OBJECT_ID('tempdb..#TMP_Packdetail') IS NOT NULL 
      DROP TABLE #TMP_Packdetail 
   
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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
      execute nsp_logerror @n_err, @c_errmsg, 'isp_PackCfmRearrangeCartonNo'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END 
END  

GO