SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: ispPAKCF07                                              */
/* Creation Date: 27-JUN-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-5159 - CN - IKEA - Exceed Packing - Enhancement Request */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 14-SEP-2018 NJOW01   1.0   WMS-6252 ECOM single pack confirm always  */
/*                            1 carton                                  */
/* 28-SEP-2018 WAN01    1.2   Call This SP below when print courier lbl */
/* 16-OCT-2018 WAN02    1.3   Issue - Remove Tracking# from CartonTrack */
/*                            If Incorrect Tracking# format due to      */
/*                            truncate                                  */
/* 09-Nov-2018 NJOW02   1.4   WMS-6934/WMS-6935 Change tacking# format  */
/*                            to remove total carton                    */
/* 31-Oct-2019 NJOW03   1.5   WMS-11049 B2B order exclude tracking no   */
/************************************************************************/
CREATE PROC [dbo].[ispPAKCF07]
           @c_PickSlipNo   NVARCHAR(10)
         , @c_Storerkey    NVARCHAR(15)
         , @b_Success      INT            OUTPUT
         , @n_Err          INT            OUTPUT
         , @c_ErrMsg       NVARCHAR(255)  OUTPUT
         , @c_CallSource   NVARCHAR(10) = ''          --(Wan01)   IF 'BARTENDER', it is Call from print Courier Label
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt          INT
         , @n_Continue           INT 

         , @n_RowRef             BIGINT
         , @n_CartonNo           INT
         , @n_EstimateTotalCtn   INT
         , @c_Orderkey           NVARCHAR(10)
         , @c_TrackingNo         NVARCHAR(20)
         , @c_CarrierName        NVARCHAR(30)
         , @c_KeyName            NVARCHAR(30)
         , @c_Child              NVARCHAR(10)
         , @c_LabelLine          NVARCHAR(5)

         , @c_CartonTrackNo      NVARCHAR(20)      --(Wan01)
         , @c_DropID             NVARCHAR(20)      --(Wan01)
         , @c_EstimateTotalCtn   NVARCHAR(10)      --(Wan01)
         , @b_Delete             BIT               --(WAN02)
         , @c_ShipperKey         NVARCHAR(15)      --NJOW03

         , @CUR_PD               CURSOR
         , @CUR_CTN              CURSOR
         , @CUR_CT               CURSOR

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''
   
   SET @c_Orderkey = ''
   SELECT @c_Orderkey = PH.Orderkey
         ,@n_EstimateTotalCtn = ISNULL(PH.EstimateTotalCtn,0)
         ,@c_ShipperKey = O.ShipperKey --NJOW03
   FROM PACKHEADER PH WITH (NOLOCK)
   JOIN ORDERS O WITH (NOLOCK) ON PH.Orderkey = O.Orderkey
   WHERE PH.PickSlipNo = @c_PickSlipNo

   IF ISNULL(@c_Orderkey,'') = ''
   BEGIN
      GOTO QUIT_SP
   END
   
   --NJOW03
   IF @c_Shipperkey = 'SN'
   BEGIN
      SET @CUR_CTN =CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT PD.CartonNo, PD.LabelLine
      FROM   PACKDETAIL PD WITH (NOLOCK)
      WHERE  PD.PickSlipNo = @c_PickSlipNo
      ORDER BY PD.CartonNo, PD.LabelLine
      
      OPEN @CUR_CTN
      
      FETCH NEXT FROM @CUR_CTN INTO @n_CartonNo, @c_LabelLine
      
      WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2)
      BEGIN     
      	 UPDATE PACKDETAIL WITH (ROWLOCK)
      	 SET DropID = LabelNo
      	 WHERE Pickslipno = @c_Pickslipno
      	 AND CartonNo = @n_CartonNo
      	 AND LabelLine = @c_LabelLine
      	 
         SET @n_Err = @@ERROR 
         
         IF @n_Err <> 0
         BEGIN
            SET @n_Continue = 3
            SET @c_ErrMsg   = CONVERT(NVARCHAR(250), @n_Err) 
            SET @n_Err = 66500
            SET @c_ErrMsg = 'NSQL' + CONVERT(NCHAR(5), @n_Err) + ': Update PACKDETAIL record(s) failed. (ispPAKCF07)'
                          + ' ( SQLSvr MESSAGE=' + RTRIM(@c_ErrMsg) + ' )'
         END
      	       	
         FETCH NEXT FROM @CUR_CTN INTO @n_CartonNo, @c_LabelLine
      END
      CLOSE @CUR_CTN
      DEALLOCATE @CUR_CTN      
   	  
      GOTO QUIT_SP
   END
      
   SET @c_TrackingNo = ''
   SELECT TOP 1 
          @c_TrackingNo = ISNULL(RTRIM(TrackingNo),'')
         ,@c_CarrierName= ISNULL(RTRIM(CarrierName),'')
         ,@c_KeyName    = ISNULL(RTRIM(KeyName),'')
   FROM CARTONTRACK WITH (NOLOCK)
   WHERE LabelNo = @c_Orderkey
   AND   CarrierRef2 = 'GET'
   ORDER BY AddDate

   IF @c_TrackingNo = ''
   BEGIN
      GOTO QUIT_SP
   END

   --NJOW01
   IF EXISTS(SELECT 1
             FROM ORDERS (NOLOCK)
             WHERE Orderkey = @c_Orderkey
             AND ECOM_SINGLE_Flag = 'S')
   BEGIN
      SET @n_EstimateTotalCtn = 1
   END   

   SET @c_EstimateTotalCtn = RTRIM(CONVERT(NVARCHAR(10),@n_EstimateTotalCtn)) --(Wan01)

   --(Wan01) - START
   IF @c_CallSource = ''
   BEGIN
      BEGIN TRAN
   END
   --(Wan01) - END

   /* --NJOW02 Removed
   SET @CUR_CT = CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT RowRef
        , CartonTrackNo = ISNULL(RTRIM(TrackingNo),'')   --(Wan01)
   FROM CARTONTRACK WITH (NOLOCK)
   WHERE LabelNo = @c_Orderkey
   AND   CarrierRef2 = 'GET'
   ORDER BY TrackingNo DESC

   OPEN @CUR_CT
   
   FETCH NEXT FROM @CUR_CT INTO @n_RowRef
                              , @c_CartonTrackNo         --(Wan01)

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @b_Delete = 0                                                          --(Wan02)
      IF RIGHT(@c_CartonTrackNo,1) = '-' AND                                     --(Wan01) 
         CHARINDEX('-' + @c_EstimateTotalCtn + '-#', @c_CartonTrackNo + '#') = 0 --(Wan01)                                 
      BEGIN
         SET @b_Delete = 1                                                       --(Wan02)
      END

      --(Wan02) - START
      IF @b_Delete = 0
      BEGIN
         IF RIGHT(@c_CartonTrackNo,1) <> '-' AND
            CHARINDEX('-', @c_CartonTrackNo) > 0
         BEGIN
            SET @b_Delete = 1 
         END
      END
      --(Wan02) - END

      IF @b_Delete = 1                                                           --(Wan02) 
      BEGIN                                                                      --(Wan02)
         DELETE CARTONTRACK 
         WHERE RowRef = @n_RowRef

         SET @n_Err = @@ERROR 
         IF @n_Err <> 0
         BEGIN
            SET @n_Continue = 3
            SET @c_ErrMsg   = CONVERT(NVARCHAR(250), @n_Err) 
            SET @n_Err = 66510
            SET @c_ErrMsg = 'NSQL' + CONVERT(NCHAR(5), @n_Err) + ': Delete CARTONTRACK record(s) fail. (ispPAKCF07)'
                          + ' ( SQLSvr MESSAGE=' + RTRIM(@c_ErrMsg) + ' )'
            GOTO QUIT_SP
         END
      END

      FETCH NEXT FROM @CUR_CT INTO @n_RowRef
                                 , @c_CartonTrackNo      --(Wan01)
   END
   CLOSE @CUR_CT
   DEALLOCATE @CUR_CT
   */

   SET @CUR_CTN =CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT PD.CartonNo
   FROM   PACKDETAIL PD WITH (NOLOCK)
   WHERE  PD.PickSlipNo = @c_PickSlipNo
   ORDER BY PD.CartonNo

   OPEN @CUR_CTN
   
   FETCH NEXT FROM @CUR_CTN INTO @n_CartonNo
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      --SET @c_Child = '-' + RTRIM(CONVERT(NVARCHAR(10), @n_CartonNo)) + '-' + CONVERT(NVARCHAR(10), @n_EstimateTotalCtn) + '-'
      SET @c_Child = '-' + RTRIM(CONVERT(NVARCHAR(10), @n_CartonNo))  --NJOW02

      SET @CUR_PD =CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT PD.LabelLine
         ,   DropID = ISNULL(RTRIM(PD.DropID),'')                 --(Wan01)
      FROM   PACKDETAIL PD WITH (NOLOCK)
      WHERE  PD.PickSlipNo = @c_PickSlipNo
      AND    PD.CartonNo = @n_CartonNo
      ORDER BY PD.LabelLine

      OPEN @CUR_PD
   
      FETCH NEXT FROM @CUR_PD INTO @c_LabelLine
                                  ,@c_DropID                      --(Wan01) 
      WHILE @@FETCH_STATUS <> -1
      BEGIN

         IF @c_DropID <> @c_TrackingNo + @c_Child                 --(Wan01)  
         BEGIN                                                    --(Wan01)            
            UPDATE PACKDETAIL WITH (ROWLOCK)
            SET DropID = @c_TrackingNo + @c_Child
            WHERE PickSlipNo = @c_PickSlipNo
            AND   CartonNo = @n_CartonNo
            AND   LabelLine= @c_LabelLine

            SET @n_Err = @@ERROR 
            IF @n_Err <> 0
            BEGIN
               SET @n_Continue = 3
               SET @c_ErrMsg   = CONVERT(NVARCHAR(250), @n_Err) 
               SET @n_Err = 66520
               SET @c_ErrMsg = 'NSQL' + CONVERT(NCHAR(5), @n_Err) + ': Update PACKDETIL Fail. (ispPAKCF07)'
                             + ' ( SQLSvr MESSAGE=' + RTRIM(@c_ErrMsg) + ' )'
               GOTO QUIT_SP
            END
         END                                                      --(Wan01)  

         FETCH NEXT FROM @CUR_PD INTO @c_LabelLine
                                    , @c_DropID                   --(Wan01)  
      END
      CLOSE @CUR_PD
      DEALLOCATE @CUR_PD

      --(Wan01) - START
      IF EXISTS ( SELECT 1
                  FROM CartonTrack WITH (NOLOCK)
                  WHERE TrackingNo = @c_TrackingNo + @c_Child
                  AND LabelNo  = @c_Orderkey
                  AND CarrierRef2 = 'GET'
               )                                           
      BEGIN
         GOTO NEXT_CARTON
      END 
      --(Wan01) - NEXT                                                  

      INSERT INTO CARTONTRACK 
            (  TrackingNo
            ,  CarrierName
            ,  KeyName
            ,  LabelNo
            ,  CarrierRef2
            )
      VALUES(  
               @c_TrackingNo + @c_Child
            ,  @c_CarrierName
            ,  @c_KeyName + '_Child'
            ,  @c_Orderkey
            ,  'GET'
            )

      SET @n_Err = @@ERROR 
      IF @n_Err <> 0
      BEGIN
         SET @n_Continue = 3
         SET @c_ErrMsg   = CONVERT(NVARCHAR(250), @n_Err) 
         SET @n_Err = 66530
         SET @c_ErrMsg = 'NSQL' + CONVERT(NCHAR(5), @n_Err) + ': Update CARTONTRACK Fail. (ispPAKCF07) '
                       + ' ( SQLSvr MESSAGE=' + RTRIM(@c_ErrMsg) + ' )'
         GOTO QUIT_SP
      END

      NEXT_CARTON:                                                --(Wan01)             

      FETCH NEXT FROM @CUR_CTN INTO @n_CartonNo                              
   END
   CLOSE @CUR_CTN
   DEALLOCATE @CUR_CTN
 
QUIT_SP:
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      IF @c_CallSource = ''               --(Wan01)
      BEGIN                               --(Wan01)
         SET @b_Success = 0
         IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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
      END                                 --(Wan01)
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispPAKCF07'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      IF @c_CallSource = ''               --(Wan01)
      BEGIN                               --(Wan01)
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END               
      END                                 --(Wan01)
   END
END -- procedure

GO