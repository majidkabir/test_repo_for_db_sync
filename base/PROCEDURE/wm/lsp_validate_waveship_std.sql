SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/*************************************************************************/  
/* Stored Procedure: lsp_Validate_WaveShip_Std                           */  
/* Creation Date: 17-Jun-2019                                            */  
/* Copyright: LFL                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose:                                                              */  
/*                                                                       */  
/* Called By:                                                            */  
/*                                                                       */  
/*                                                                       */  
/* Version: 8.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */ 
/* 2021-02-10   mingle01 1.1  Add Big Outer Begin try/Catch              */
/*************************************************************************/   
CREATE PROC [WM].[lsp_Validate_WaveShip_Std] (
      @c_MBOLkey              NVARCHAR(10)  = ''              
   ,  @b_Success              INT = 1                 OUTPUT  
   ,  @n_err                  INT = 0                 OUTPUT                                                                                                             
   ,  @c_ErrMsg               NVARCHAR(255)= ''       OUTPUT 
) AS 
BEGIN
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF     

   DECLARE @n_Continue                       INT = 1

         , @c_StorerKey                      NVARCHAR(15) = ''
         , @c_Facility                       NVARCHAR(15) = ''          
         , @c_Vessel                         NVARCHAR(30) = ''
         , @c_Drivername                     NVARCHAR(30) = ''
         , @c_CarrierKey                     NVARCHAR(10) = ''
         , @c_Userdefine05                   NVARCHAR(20) = '' 
         , @c_Userdefine09                   NVARCHAR(10) = ''
         , @c_Userdefine10                   NVARCHAR(10) = ''
         , @c_ShipperAcctCode                NVARCHAR(15) = ''
         , @c_ShipToAcctCode                 NVARCHAR(15) = ''
         , @dt_ArrivalDateFinalDestination   DATETIME 

         , @b_ValidCarrier                   INT          = 0      
         , @b_ValidShipper                   INT          = 0   
         , @b_ValidShipTo                    INT          = 0   
   -- StorerConfig 
   DECLARE 
         @c_MBOLDeliveryInfo                 NVARCHAR(1) = '0'
      ,  @c_CheckProFormABOL                 NVARCHAR(1) = '0'
   
   SET @b_Success = 1
   SET @n_err = 0
   SET @c_ErrMsg = ''
   
   --(mingle01) - START
   BEGIN TRY
      SELECT  
            @c_Vessel         = ISNULL(MB.Vessel,'')
         ,  @c_Drivername     = ISNULL(MB.Drivername,'')
         ,  @c_CarrierKey     = ISNULL(MB.CarrierKey,'')
         ,  @c_Userdefine05   = ISNULL(MB.Userdefine05,'')   
         ,  @c_Userdefine09   = ISNULL(MB.Userdefine09,'')    
         ,  @c_Userdefine10   = ISNULL(MB.Userdefine10,'')    
         ,  @c_ShipperAcctCode= ISNULL(MB.ShipperAccountCode,'')
         ,  @c_ShipToAcctCode = ISNULL(MB.ConsigneeAccountCode,'') 
         ,  @dt_ArrivalDateFinalDestination = MB.ArrivalDateFinalDestination
      FROM MBOL MB WITH (NOLOCK) 
      WHERE MB.MBOLKey = @c_MBOLKey            

      SELECT TOP 1 @c_Storerkey = OH.Storerkey
            , @c_Facility = OH.Orderkey
      FROM MBOLDETAIL MD WITH (NOLOCK)
      JOIN ORDERS     OH WITH (NOLOCK) ON MD.Orderkey = OH.Orderkey
      WHERE MD.MBOLKey = @c_MBOLKey

      IF @c_Storerkey = ''
      BEGIN
         GOTO EXIT_SP
      END

      SELECT @c_MBOLDeliveryInfo = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'MBOLDeliveryInfo')
      SELECT @c_CheckProFormABOL = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'CheckProFormABOL')

      IF @c_MBOLDeliveryInfo = '1'
      BEGIN
         IF @c_Vessel = ''
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 556851
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Vehicle Number is required'
                          + '. (lsp_Validate_WaveShip_Std)'
            GOTO EXIT_SP
         END

         IF @c_Drivername = ''
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 556852
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Driver Name is required'
                          + '. (lsp_Validate_WaveShip_Std)'
            GOTO EXIT_SP
         END

         IF @dt_ArrivalDateFinalDestination IS NULL OR @dt_ArrivalDateFinalDestination = CONVERT(DATETIME, '1900-01-01')
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 556853
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Delivery Date is required'
                          + '. (lsp_Validate_WaveShip_Std)'
            GOTO EXIT_SP
         END
      END

      IF @c_CheckProFormABOL = '1'
      BEGIN
         IF @c_Userdefine05 = ''
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 556854
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': UserDefine05 is required PRODUCT SEAL'
                          + '. (lsp_Validate_WaveShip_Std)'
            GOTO EXIT_SP
         END

         IF @c_Userdefine09 = ''
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 556855
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': UserDefine09 is required for FORWARDER SEAL'
                          + '. (lsp_Validate_WaveShip_Std)'
            GOTO EXIT_SP
         END

         IF @c_Userdefine10 = ''
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 556856
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': UserDefine10 is required for Van'
                          + '. (lsp_Validate_WaveShip_Std)'
            GOTO EXIT_SP
         END

         SELECT @b_ValidCarrier = ISNULL(SUM(CASE WHEN Storerkey = @c_CarrierKey THEN 1 ELSE 0 END),0)
               ,@b_ValidShipper = ISNULL(SUM(CASE WHEN Storerkey = @c_ShipperAcctCode THEN 1 ELSE 0 END),0)
               ,@b_ValidShipTo  = ISNULL(SUM(CASE WHEN Storerkey = @c_ShipToAcctCode THEN 1 ELSE 0 END),0)
         FROM STORER WITH (NOLOCK)
         WHERE Storerkey IN (@c_CarrierKey, @c_ShipperAcctCode, @c_ShipToAcctCode)

         IF @b_ValidCarrier = 0 
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 556857
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': CarrierKey Must be Valid StorerKey'
                          + '. (lsp_Validate_WaveShip_Std)'
            GOTO EXIT_SP
         END

         IF @b_ValidShipper = 0 
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 556858
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Shipper Must be Valid StorerKey'
                          + '. (lsp_Validate_WaveShip_Std)'
            GOTO EXIT_SP
         END

         IF @b_ValidShipTo = 0 
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 556859
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Ship To Must be Valid StorerKey'
                          + '. (lsp_Validate_WaveShip_Std)'
            GOTO EXIT_SP
         END
      END
   END TRY
   
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH
   --(mingle01) - END
   EXIT_SP:
   IF @n_Continue = 3
   BEGIN
      SET @b_Success = 0 
   END
   
END -- Procedure

GO