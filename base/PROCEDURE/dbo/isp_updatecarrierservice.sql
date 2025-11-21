SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/********************************************************************************/
/* Stored Procedure: isp_UpdateCarrierService                           				*/
/* Creation Date: 12-03-2012                                            				*/
/* Copyright: IDS                                                       				*/
/* Written by: YTWan                                                    				*/
/*                                                                      				*/
/* Purpose: SOS#239197-Agile Elite-Carrier Maintenance                  				*/
/*          Move Update Orders to SP                                    				*/
/*                                                                      				*/
/* Called By: Call from Carrier Service Maintenance - Update Carrier    				*/
/*            Service IF Carrier (Orders.SpecialHandling) OR Service    				*/ 
/*            Type(ORDERS.M_Phone2) is changed                          				*/
/*                                                                      				*/
/* Parameters:                                                          				*/
/*                                                                      				*/
/* PVCS Version: 1.0                                                    				*/
/*                                                                      				*/
/* Version: 5.4                                                         				*/
/*                                                                      				*/
/* Data Modifications:                                                  				*/
/*                                                                      				*/
/* Updates:                                                             				*/
/* Date         Author    Ver.  Purposes                                				*/
/* 27-03-2012   ChewKP    1.01  TransmitLog3 Update (ChewKP01)          				*/ 
/* 06-Apr-2012  YTWan     1.1   Insert Transmitlog3 or reprint label if 				*/
/*                              Carrier (Orders.SpecialHandling) OR     				*/ 
/*                              ServiceType(ORDERS.M_Phone2) is changed 				*/ 
/*                              . - Checking done before calling this SP				*/
/*                              (Wan01)                                 				*/
/* 22-Apr-2012  SHONG     1.2   Store Previous Service Type (M_Phone2) to       */
/*                              Transmitlog2 Key2, need to retrigger tracking#  */
/* 01-May-2012  SHONG     1.3   Wrong KeyName use for Transmitlog3              */
/* 27-Jun-2012  ChewKP    1.4   SOS#248678 - Update DropIDDetail.LabelPrinted = ''  */
/*                              (ChewKP02)                                          */
/* 13-Mar-2013  SPChin    1.5   SOS271299 Bug Fixed                                 */
/* 15-APR-2013  YTWan     1.6   SOS#274535-Carrier Change / Label Requirement(Wan02)*/
/********************************************************************************/

CREATE PROC [dbo].[isp_UpdateCarrierService]
      @c_Orderkey    NVARCHAR(10)
   ,  @c_Carrier     NVARCHAR(1) 
   ,  @b_success     INT         OUTPUT
   ,  @n_err         INT         OUTPUT
   ,  @c_errmsg      NVARCHAR(225)   OUTPUT    
   ,  @c_ServiceType NVARCHAR(18) = ' '                                                             --(Wan02)
   ,  @c_Scac        NVARCHAR(20) = ' '                                                             --(Wan02)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue           INT
         , @n_starttcnt          INT

         , @c_Transmitlogkey     NVARCHAR(10)
         , @c_Storerkey          NVARCHAR(15)
         , @c_SpecialHandling    NVARCHAR(1)
         , @c_TransmitLogCarrier NVARCHAR(1) -- (ChewKP01)
         , @c_ServType           NVARCHAR(10)
         , @c_TransmitLogServTyp NVARCHAR(4)
         , @c_Key2               NVARCHAR(5)
         
         , @c_PServiceType       NVARCHAR(18) --(Wan02)
         , @c_PSCAC              NVARCHAR(30) --(Wan02)
         
   SET @b_success  = 0
   SET @n_err      = 0
   SET @c_errmsg   = ''

   SET @n_Continue = 1
   SET @n_StartTCnt= @@TRANCOUNT

   SET @c_Transmitlogkey = ''
   SET @c_Storerkey      = ''
   SET @c_SpecialHandling= ''
   SET @c_TransmitLogCarrier = '' -- (ChewKP01)

   SET @c_PServiceType   = ''       --(Wan02)
   SET @c_PSCAC          = ''       --(Wan02)
   
   SET @c_ServType = ''
   SET @c_SpecialHandling=''
   SELECT @c_Storerkey = RTRIM(Storerkey)
         ,@c_SpecialHandling = ISNULL(LEFT(RTRIM(SpecialHandling),1),'')
         ,@c_ServType        = ISNULL(LEFT(RTRIM(M_Phone2),4),'')
         ,@c_PServiceType    = ISNULL(RTRIM(M_Phone2),'')                                          --(Wan02) 
         ,@c_PSCAC           = ISNULL(RTRIM(UserDefine02),'')                                      --(Wan02)
   FROM ORDERS WITH (NOLOCK)
   WHERE Orderkey = @c_Orderkey

   EXECUTE nspg_GetKey
    'TransmitlogKey3'
   ,10 
   ,@c_Transmitlogkey   OUTPUT 
   ,@b_success   	      OUTPUT 
   ,@n_err       	      OUTPUT 
   ,@c_errmsg    	      OUTPUT

   IF @b_success = 0
   BEGIN
      SET @n_continue = 3
      SET @n_err = 30101
      SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Error Getting New loadkey. (isp_UpdateCarrierService)' 
                    + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
      GOTO QUIT
   END   

   SET @c_Key2 = CASE WHEN ISNULL(RTRIM(@c_SpecialHandling),'') = '' THEN ' ' ELSE @c_SpecialHandling END +
                 ISNULL(RTRIM(@c_ServType),'')

   INSERT INTO TRANSMITLOG3 (Transmitlogkey, TableName, Key1, Key2, Key3)
   VALUES (@c_Transmitlogkey, 'CHANGE_CARRIER_LOG', @c_Orderkey, @c_Key2, @c_Storerkey) --SOS271299
   SET @n_err = @@ERROR
   IF @n_err <> 0         
   BEGIN          
      SET @n_continue = 3    
      SET @n_err = 30102
      SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Error Insert Into Transmitlog3. (isp_UpdateCarrierService)' 
                    + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
      GOTO QUIT      
   END  

   -- IF All TransmitFlag = 0 , and Last Orders SpecialHandling Change = First record of Transmitlog3 , 
   -- Update all transmitflag = '9' Indicate Nothing to be done
   -- (ChewKP01)
   
--   IF EXISTS     ( SELECT 1 FROM dbo.TransmitLog3 WITH (NOLOCK) -- (ChewKP02)
--                   WHERE TableName = 'CHANGE_CARRIER_LOG'         -- Add Tablename checking
--                     AND Key1 = @c_orderkey
--                     AND Key3 = @c_Storerkey
--                     AND TransmitFlag = '9' )
--   BEGIN
      --(Wan02) - START 
--    SELECT TOP 1 @c_TransmitLogCarrier = LEFT(Key2,1), 
--                 @c_TransmitLogServTyp = SUBSTRING(Key2, 2, 4)
--    FROM dbo.TransmitLog3 WITH (NOLOCK)
--    WHERE TableName = 'CHANGE_CARRIER_LOG'                      -- Add Tablename checking
--      AND Key1 = @c_orderkey
--      AND Key3 = @c_Storerkey
--    ORDER BY TransmitLogKey
      --(Wan02) - END 
      
    --IF @c_TransmitLogCarrier = @c_Carrier --AND @c_TransmitLogServTyp = @c_ServType					--(Wan02)
    IF @c_Carrier = 'N' AND (@c_SpecialHandling <> @c_Carrier OR @c_PSCAC <> @c_SCAC)					--(Wan02)				
    BEGIN
       UPDATE TransmitLog3 SET  
             TransmitFlag = '9'  
       WHERE TableName = 'CHANGE_CARRIER_LOG'                  -- Add Tablename checking 
         AND Key1 = @c_orderkey
         AND Key3 = @c_Storerkey
      	  AND Transmitflag = '0'                                --(Wan02)
       
       SET @n_err = @@ERROR
    	IF @n_err <> 0
       BEGIN
          SET @n_continue = 3
          SET @n_err = 30104
          SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Error Update TransmitLog3 Table. (isp_UpdateCarrierService)' 
                        + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
          GOTO QUIT
       END
       
       IF EXISTS ( SELECT 1
                FROM ORDERDETAIL WITH (NOLOCK)
                LEFT JOIN PACKHEADER WITH (NOLOCK) ON (ORDERDETAIL.Orderkey = PACKHEADER.Orderkey)
                LEFT JOIN PACKHEADER CSPH WITH (NOLOCK) ON (ORDERDETAIL.ConsoOrderkey = CSPH.ConsoOrderkey)
                JOIN PACKDETAIL WITH (NOLOCK) ON (ISNULL(RTRIM(CSPH.PickSlipNo),RTRIM(PACKHEADER.PickSlipNo)) = PACKDETAIL.PickSlipNo)
                JOIN DROPIDDETAIL WITH (NOLOCK) ON (PACKDETAIL.LabelNo = DROPIDDETAIL.Childid)
                WHERE ORDERDETAIL.Orderkey = @c_orderkey )
       BEGIN
          UPDATE DROPIDDETAIL WITH (ROWLOCK)
           SET DROPIDDETAIL.LabelPrinted = 'Y'
   	         ,  DROPIDDETAIL.EditWho = SUSER_NAME()
   	         ,  DROPIDDETAIL.EditDate= GETDATE()
             ,  DROPIDDETAIL.Trafficcop = NULL
          FROM ORDERDETAIL WITH (NOLOCK)
          LEFT JOIN PACKHEADER WITH (NOLOCK) ON (ORDERDETAIL.Orderkey = PACKHEADER.Orderkey)
          LEFT JOIN PACKHEADER CSPH WITH (NOLOCK) ON (ORDERDETAIL.ConsoOrderkey = CSPH.ConsoOrderkey)
          JOIN PACKDETAIL WITH (NOLOCK) ON (ISNULL(RTRIM(CSPH.PickSlipNo),RTRIM(PACKHEADER.PickSlipNo)) = PACKDETAIL.PickSlipNo)
          JOIN DROPIDDETAIL ON (PACKDETAIL.LabelNo = DROPIDDETAIL.Childid)
          WHERE ORDERDETAIL.Orderkey = @c_orderkey
   
          SET @n_err = @@ERROR
   	      IF @n_err <> 0
          BEGIN
             SET @n_continue = 3
             SET @n_err = 30105
             SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Error Update DROPIDDETAIL Table. (isp_UpdateCarrierService)' 
                           + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
             GOTO QUIT
          END
   	   END -- If Exists         
    END -- IF @c_TransmitLogCarrier = @c_Carrier
   ELSE IF @c_Carrier IN ( 'U', 'X') AND (@c_SpecialHandling <> @c_Carrier OR @c_PServiceType <> @c_ServiceType)			--(Wan02)
   BEGIN
      IF EXISTS ( SELECT 1
                  FROM ORDERDETAIL WITH (NOLOCK)
                  LEFT JOIN PACKHEADER WITH (NOLOCK) ON (ORDERDETAIL.Orderkey = PACKHEADER.Orderkey)
                  LEFT JOIN PACKHEADER CSPH WITH (NOLOCK) ON (ORDERDETAIL.ConsoOrderkey = CSPH.ConsoOrderkey)
                  JOIN PACKDETAIL WITH (NOLOCK) ON (ISNULL(RTRIM(CSPH.PickSlipNo),RTRIM(PACKHEADER.PickSlipNo)) = PACKDETAIL.PickSlipNo)
                  JOIN DROPIDDETAIL WITH (NOLOCK) ON (PACKDETAIL.LabelNo = DROPIDDETAIL.Childid)
                  WHERE ORDERDETAIL.Orderkey = @c_orderkey )
      BEGIN
   
         UPDATE DROPIDDETAIL WITH (ROWLOCK)
         SET   DROPIDDETAIL.LabelPrinted = ''
   	      ,  DROPIDDETAIL.EditWho = SUSER_NAME()
   	      ,  DROPIDDETAIL.EditDate= GETDATE()
            ,  DROPIDDETAIL.Trafficcop = NULL
         FROM ORDERDETAIL WITH (NOLOCK)
         LEFT JOIN PACKHEADER WITH (NOLOCK) ON (ORDERDETAIL.Orderkey = PACKHEADER.Orderkey)
         LEFT JOIN PACKHEADER CSPH WITH (NOLOCK) ON (ORDERDETAIL.ConsoOrderkey = CSPH.ConsoOrderkey)
         JOIN PACKDETAIL WITH (NOLOCK) ON (ISNULL(RTRIM(CSPH.PickSlipNo),RTRIM(PACKHEADER.PickSlipNo)) = PACKDETAIL.PickSlipNo)
         JOIN DROPIDDETAIL ON (PACKDETAIL.LabelNo = DROPIDDETAIL.Childid)
         WHERE ORDERDETAIL.Orderkey = @c_orderkey
   
         SET @n_err = @@ERROR
   	   IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_err = 30103
            SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Error Update DROPIDDETAIL Table. (isp_UpdateCarrierService)' 
                          + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
            GOTO QUIT
         END
   	END
   END
   
   QUIT:
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_UpdateCarrierService'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
	ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END	   
END

GO