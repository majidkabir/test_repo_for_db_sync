SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: isp_ValidateCarrierChange                           */  
/* Creation Date: 21-MAR-2012                                            */  
/* Copyright: IDS                                                        */  
/* Written by: YTWan                                                     */  
/*                                                                       */  
/* Purpose: SOS#239197-Agile Elite-Carrier Maintenance                   */  
/*                                                                       */  
/* Called By: Call from Carrier Service Maintenance - Update Carrier     */
/*            Service                                                    */  
/*                                                                       */  
/* PVCS Version: 1.0                                                     */  
/*                                                                       */  
/* Version: 5.4                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */  
/*************************************************************************/  

CREATE PROC [dbo].[isp_ValidateCarrierChange]  
      @c_Orderkey    NVARCHAR(10)
   ,  @b_success     INT            OUTPUT
   ,  @n_Err         INT            OUTPUT
   ,  @c_ErrMsg      NVARCHAR(255)   OUTPUT
AS  
BEGIN
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @n_Continue           INT
         , @n_CartonInStage      INT
         , @n_CartonReadyToShip  INT
         
         , @c_Wavekey            NVARCHAR(10)
         , @c_Storerkey          NVARCHAR(15)
         , @c_B_Fax2             NVARCHAR(30)
         , @c_B_Fax1_13_1        NVARCHAR(1)


   SET @b_success           = 1
   SET @n_Err               = 0
   SET @c_ErrMsg            = ''

   SET @n_Continue          = 1
   SET @n_CartonInStage     = 0
   SET @n_CartonReadyToShip = 0

   SET @c_Wavekey           = ''
   SET @c_Storerkey         = ''
   SET @c_B_Fax2            = ''
   SET @c_B_Fax1_13_1       = ''

   SELECT @c_Wavekey = RTRIM(WAVEDETAIL.Wavekey)
         ,@c_Storerkey = RTRIM(ORDERS.Storerkey)
         ,@c_B_Fax2 = ISNULL(RTRIM(ORDERS.B_Fax2),'')
         ,@c_B_Fax1_13_1 = SUBSTRING(ORDERS.B_Fax1,13,1) --CASE WHEN LEN(ORDERS.B_Fax1) > 13 THEN SUBSTRING(ORDERS.B_Fax1,13,1) ELSE '' END
   FROM ORDERS WITH (NOLOCK)
   JOIN WAVEDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = WAVEDETAIL.Orderkey)
   WHERE ORDERS.Orderkey = @c_Orderkey

   IF @c_Wavekey = '' GOTO QUIT_SP 

   -- Check Release to WCS
   IF NOT EXISTS ( SELECT 1 
                   FROM TRANSMITLOG3 WITH (NOLOCK)
                   WHERE TableName = 'WAVERESLOG'  
                   AND   Key1 = @c_Wavekey 
                   AND   Key3 = @c_Storerkey )
   BEGIN
      GOTO QUIT_SP 
   END
   --Check Fluid Load requires
   IF @c_B_Fax2 <> '' AND UPPER(@c_B_Fax1_13_1) = 'N'
   BEGIN
      SET @n_continue = 3
      SET @c_ErrMsg = 'Fluid load is required for Orderkey: ' + @c_Orderkey 
      GOTO QUIT_SP
   END

   SELECT @n_CartonInStage = ISNULL(SUM(tmp.PalletInStage),0)
         ,@n_CartonReadyToShip = ISNULL(MIN(tmp.PalletInStage) + 1,0) 
   FROM (
         SELECT PalletInStage = CASE WHEN DROPID.DropIDType = 'PALLET' AND LOC.LocationCategory IN ('STAGING','Pack&Hold') THEN 1 ELSE 0 END
         FROM ORDERDETAIL WITH (NOLOCK)
         LEFT JOIN PACKHEADER WITH (NOLOCK) ON (ORDERDETAIL.Orderkey = PACKHEADER.Orderkey)
         LEFT JOIN PACKHEADER CSPH WITH (NOLOCK) ON (ORDERDETAIL.ConsoOrderkey = CSPH.ConsoOrderkey)
         JOIN PACKDETAIL WITH (NOLOCK) ON (ISNULL(RTRIM(CSPH.PickSlipNo),RTRIM(PACKHEADER.PickSlipNo)) = PACKDETAIL.PickSlipNo)
         JOIN DROPIDDETAIL (NOLOCK) ON (PACKDETAIL.LabelNo = DROPIDDETAIL.Childid)
         JOIN DROPID ON (DROPIDDETAIL.Dropid = DROPID.Dropid)
         JOIN LOC ON (DROPID.Droploc = LOC.Loc)
         WHERE ORDERDETAIL.Orderkey = @c_Orderkey ) tmp

   IF @n_CartonInStage = 0 OR @n_CartonReadyToShip = 1
   BEGIN
      SET @n_continue = 3
      --SET @c_ErrMsg = 'Orderkey: ' + @c_Orderkey + '''s carton not in Staging OR Pack&Hold Location.'
      SET @c_ErrMsg = 'Orders have been released. Carrier Change not permitted Until Picked & Palletized. Order(s) -:' + @c_Orderkey
      GOTO QUIT_SP
   END

                    
   QUIT_SP:
   SET @b_success = 1

   IF @n_continue = 3
   BEGIN
      SET @b_success = 0
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_ValidateCarrierChange'  
   END   
END

GO