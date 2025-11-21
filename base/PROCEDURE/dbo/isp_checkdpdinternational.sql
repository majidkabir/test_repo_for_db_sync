SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: isp_CheckDPDInternational                           */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Check valid data before allowing to print DPD label for     */  
/*          International                                               */
/* Called from: rdt_EcommDispatch_Confirm                               */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author Purposes                                     */  
/************************************************************************/  
CREATE PROC [dbo].[isp_CheckDPDInternational]   
   @c_StorerKey   NVARCHAR(15),  
   @c_OrderKey    NVARCHAR(10),   
   @b_success  int = 1 OUTPUT,  
   @n_err      int = 0 OUTPUT,  
   @c_errmsg   NVARCHAR(225) = '' OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON     
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF      
  
   
   DECLARE  @c_trackno  NVARCHAR(15),  
         @c_susr1    NVARCHAR(20),       
         @c_susr2    NVARCHAR(20),   
         @c_m_vat    NVARCHAR(18),    --to store parcel number       
         @c_cdigit   NVARCHAR(1)
   
      SELECT   @c_susr1    = RTRIM(ISNULL(STORER.SUSR1,'')),   
               @c_susr2    = RTRIM(ISNULL(STORER.SUSR2,''))
      FROM STORER WITH (NOLOCK) WHERE STORER.StorerKey = 'IDS'  
  
      SELECT @c_m_vat = RTRIM(ISNULL(ORDERS.M_Vat,''))
      FROM ORDERS WITH (NOLOCK)  
      WHERE ORDERS.OrderKey = @c_OrderKey   
      AND ORDERS.StorerKey = @c_StorerKey   
        
      IF @c_m_vat = ''   
      BEGIN  
         EXECUTE nspg_GetKey  
            'PARCELNO',   
            6,  
            @c_m_vat    OUTPUT,  
            @b_success  OUTPUT,  
            @n_err      OUTPUT,  
            @c_errmsg   OUTPUT  
              
         IF @b_success <> 1  
         BEGIN   
            SET @n_err = 60001  
            SET @c_errmsg = 'FAIL To Generate Parcel Number. isp_CheckDPDInternational'  
            GOTO QUIT  
         END   

         UPDATE ORDERS WITH (ROWLOCK)      
         SET M_Vat = @c_m_vat   
         WHERE ORDERS.OrderKey = @c_OrderKey   
         AND ORDERS.StorerKey = @c_StorerKey   
           
         UPDATE PackInfo WITH (ROWLOCK)      
         SET RefNo = @c_m_vat   
         FROM PackHeader WITH (NOLOCK)  
         WHERE PackHeader.OrderKey = @c_OrderKey    
         AND PackHeader.StorerKey = @c_StorerKey  
         AND PackInfo.PickSlipNo = PackHeader.PickSlipNo  
      END  
  
      SET @c_trackno = RTRIM(@c_susr1) + RTRIM(@c_susr2) + RTRIM(@c_m_vat)  
        
      EXEC isp_CheckDigitsISO7064   
         @c_trackno,   
         @b_success OUTPUT,   
         @c_cdigit  OUTPUT  
        
      IF @b_success <> 1  
      BEGIN   
         SET @n_err = 60002  
         SET @c_errmsg = 'FAIL To Check Digit for Parcel Number. isp_CheckDPDInternational'  
         GOTO QUIT  
      END   

  
   QUIT:   
END

GO