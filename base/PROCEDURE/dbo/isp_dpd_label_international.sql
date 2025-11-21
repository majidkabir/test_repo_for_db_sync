SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: isp_DPD_Label_International                         */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Print DPD label International (SOS#179945)                  */
/*          by GTGOH 14Jul2010                                          */
/* Called from: r_dw_dpd_label_international                            */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author Purposes                                     */
/* 28Jul2010   1.0  GTGOH  SOS#183250 - Add in refno as parameter to be */    
/*                         print in report module  (GOH01)              */  
/************************************************************************/
CREATE PROC [dbo].[isp_DPD_Label_International] 
   @c_StorerKey   NVARCHAR(15),
   @c_OrderKey    NVARCHAR(10), 
   @c_RefNo     NVARCHAR(28) = '',    --GOH01
   @b_success  int = 1 OUTPUT,
   @n_err      int = 0 OUTPUT,
   @c_errmsg   NVARCHAR(225) = '' OUTPUT
AS
BEGIN
   SET NOCOUNT ON			
   SET QUOTED_IDENTIFIER OFF	
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF    

	
DECLARE  @c_accno    NVARCHAR(6), 
         @c_idsname  NVARCHAR(45), 
         @c_add1     NVARCHAR(45),
         @c_add2     NVARCHAR(45),
         @c_add3     NVARCHAR(45),
         @c_add4     NVARCHAR(45),
         @c_contact1 NVARCHAR(30),
         @c_phone1   NVARCHAR(18),
         @c_c_name    NVARCHAR(45), 
         @c_c_add1   NVARCHAR(45),
         @c_c_add2   NVARCHAR(45),
         @c_c_add3   NVARCHAR(45),
         @c_c_add4   NVARCHAR(45),
         @c_c_contact1  NVARCHAR(30),
         @c_c_phone1 NVARCHAR(18),
         @c_trackno  NVARCHAR(15),
         @c_srvdesc  NVARCHAR(30),
         @c_maxweight   NVARCHAR(5),
         @c_height   NVARCHAR(5),
         @c_weight   NVARCHAR(5),
         @c_length   NVARCHAR(5),
         @c_proddesc NVARCHAR(30),     
         @c_susr1    NVARCHAR(20),     
         @c_susr2    NVARCHAR(20), 
         @c_susr3    NVARCHAR(20), 
         @c_incoterm NVARCHAR(10), 
         @c_m_vat    NVARCHAR(18),    --to store parcel number     
         @c_cdigit   NVARCHAR(1),
         @f_value    float
 
      SELECT @c_accno = RTRIM(ISNULL(STORER.VAT,'')), 
         @c_idsname  = RTRIM(ISNULL(STORER.Company,'')), 
         @c_add1     = RTRIM(ISNULL(STORER.Address1,'')),
         @c_add2     = RTRIM(ISNULL(STORER.Address2,'')),
         @c_add3     = RTRIM(ISNULL(STORER.Address3,'')),
         @c_add4     = RTRIM(ISNULL(STORER.Address4,'')),
         @c_contact1 = RTRIM(ISNULL(STORER.Contact1,'')),
         @c_phone1   = RTRIM(ISNULL(STORER.Phone1,'')), 
         @c_susr1    = RTRIM(ISNULL(STORER.SUSR1,'')), 
         @c_susr2    = RTRIM(ISNULL(STORER.SUSR2,'')), 
         @c_susr3    = RTRIM(ISNULL(STORER.SUSR3,'')) 
      FROM STORER WITH (NOLOCK) WHERE STORER.StorerKey = 'IDS'

      --GOH01 Start
      IF RTRIM(ISNULL(@c_OrderKey,'')) = '' AND RTRIM(ISNULL(@c_RefNo,'')) <> ''
      BEGIN    
         SELECT @c_OrderKey = PackHeader.OrderKey, 
               @c_StorerKey = ORDERS.StorerKey 
         FROM PackInfo WITH (NOLOCK) 
         JOIN PackHeader WITH (NOLOCK) 
         ON (PackInfo.PickSlipNo = PackHeader.PickSlipNo)
         JOIN ORDERS WITH (NOLOCK) 
         ON (PackHeader.OrderKey = ORDERS.OrderKey)
         WHERE PackInfo.RefNo = @c_RefNo 
      END
      --GOH01 End

      SELECT @c_m_vat = RTRIM(ISNULL(ORDERS.M_Vat,'')),
         @c_c_name  = RTRIM(ISNULL(ORDERS.C_Company,'')), 
         @c_c_add1     = RTRIM(ISNULL(ORDERS.C_Address1,'')),
         @c_c_add2     = RTRIM(ISNULL(ORDERS.C_Address2,'')),
         @c_c_add3     = RTRIM(ISNULL(ORDERS.C_Address3,'')),
         @c_c_add4     = RTRIM(ISNULL(ORDERS.C_Address4,'')),
         @c_c_contact1 = RTRIM(ISNULL(ORDERS.C_Contact1,'')),
         @c_c_phone1   = RTRIM(ISNULL(ORDERS.C_Phone1,'')),
         @c_incoterm   = RTRIM(ISNULL(ORDERS.IncoTerm,'')) 
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
            SET @c_errmsg = 'FAIL To Generate Parcel Number. isp_DPD_Label_International'
            GOTO QUIT
         END 
         
         UPDATE ORDERS WITH (ROWLOCK)    
         SET M_Vat = @c_m_vat 
         WHERE ORDERS.OrderKey = @c_OrderKey 
         AND ORDERS.StorerKey = @c_StorerKey 
         
         --GOH01 Start
         UPDATE PackInfo WITH (ROWLOCK)    
         SET RefNo = @c_m_vat 
         FROM PackHeader WITH (NOLOCK)
         WHERE PackHeader.OrderKey = @c_OrderKey  
         AND PackHeader.StorerKey = @c_StorerKey
         AND PackInfo.PickSlipNo = PackHeader.PickSlipNo
         --GOH01 End

      END

      SELECT @f_value = SUM(PICKDETAIL.Qty * ORDERDETAIL.UnitPrice)
      FROM ORDERDETAIL WITH(NOLOCK)
      JOIN PICKDETAIL WITH(NOLOCK)
      ON PICKDETAIL.OrderKey = ORDERDETAIL.OrderKey
      AND PICKDETAIL.OrderLineNumber = ORDERDETAIL.OrderLineNumber
      AND PICKDETAIL.Status >= 5
      JOIN ORDERS WITH(NOLOCK)
      ON ORDERDETAIL.OrderKey = ORDERS.OrderKey 
      AND ORDERDETAIL.StorerKey = ORDERS.StorerKey 
      AND ORDERS.OrderKey = @c_OrderKey 
      AND ORDERS.StorerKey = @c_StorerKey 
      GROUP BY ORDERDETAIL.OrderKey
      
      SET @c_trackno = RTRIM(@c_susr1) + RTRIM(@c_susr2) + RTRIM(@c_m_vat)
      
      EXEC isp_CheckDigitsISO7064 
         @c_trackno, 
         @b_success OUTPUT, 
	      @c_cdigit  OUTPUT
      
      IF @b_success <> 1
      BEGIN 
         SET @n_err = 60002
         SET @c_errmsg = 'FAIL To Check Digit for Parcel Number. isp_DPD_Label_International'
         GOTO QUIT
      END 
      
      SET @c_trackno = RTRIM(@c_trackno) + @c_cdigit
      
      SELECT @c_srvdesc = REPDPDSRV.DPDLabelSrvDescr,
         @c_maxweight = REPDPDSRV.MaxweightperParcel,
         @c_proddesc  = REPDPDSRV.DPDProdDescr  
      FROM REPDPDSRV WITH(NOLOCK)
      WHERE REPDPDSRV.GeoSrvCode = SUBSTRING(@c_incoterm,1,3)

   QUIT: 
      SELECT   @c_accno,  @c_idsname,  @c_add1,     @c_add2,    @c_add3,
               @c_add4,   @c_contact1, @c_phone1,   @c_c_name,  @c_c_add1,
               @c_c_add2, @c_c_add3,   @c_c_add4,   @c_c_contact1,
               @c_c_phone1,            @c_trackno,  @c_srvdesc, @c_maxweight,
               @c_height, @c_weight,   @c_length,   @c_proddesc,@f_value, 
               @c_susr3,  @c_errmsg              
               

END

GO