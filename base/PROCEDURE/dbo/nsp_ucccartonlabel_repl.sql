SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_ucccartonlabel_repl                            */
/* Creation Date: 1/22/2021                                             */
/* Copyright: LF Logistics                                              */
/* Written by:wtshong                                                   */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* GIT Version: 1.0                                                     */
/*                                                                      */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:    ver  purpose                                             */
/* 05-Apr-2004 1.0  WANYT Timberland FBR#20679: RF Replenishment With   */
/*                  UCC and UCC Pick                                    */
/************************************************************************/
CREATE PROC [dbo].[nsp_ucccartonlabel_repl] (
	@c_batchno	 NVARCHAR(20),
	@c_uccno1	 NVARCHAR(20),
	@c_uccno2	 NVARCHAR(20),
	@c_uccno3	 NVARCHAR(20),
	@c_uccno4	 NVARCHAR(20),
	@c_uccno5	 NVARCHAR(20),
	@c_uccno6	 NVARCHAR(20),
	@c_uccno7	 NVARCHAR(20),
	@c_uccno8	 NVARCHAR(20),
	@c_uccno9	 NVARCHAR(20),
	@c_uccno10	 NVARCHAR(20)
) 
as
BEGIN 
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

	declare @n_continue  		int,
		@n_starttcnt 		int,
		@local_n_err 		int,
		@local_c_errmsg  NVARCHAR(255),
		@n_cnt       		int,
		@n_rowcnt       	int,
		@b_success		int,
		@n_err			int,
		@c_errmsg	 NVARCHAR(255),
      @c_cartontype           NVARCHAR(2),
      @c_ordertype            NVARCHAR(10)
		

	select @n_starttcnt=@@trancount , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',
	       @local_n_err = 0, @local_c_errmsg = ''

	IF (@n_continue = 1 OR @n_continue = 2) 
	BEGIN	
		IF dbo.fnc_RTrim(@c_uccno1) IS NULL AND dbo.fnc_RTrim(@c_uccno2) IS NULL AND dbo.fnc_RTrim(@c_uccno3) IS NULL AND
		   dbo.fnc_RTrim(@c_uccno4) IS NULL AND dbo.fnc_RTrim(@c_uccno5) IS NULL AND dbo.fnc_RTrim(@c_uccno6) IS NULL AND 
                   dbo.fnc_RTrim(@c_uccno7) IS NULL AND dbo.fnc_RTrim(@c_uccno8) IS NULL AND dbo.fnc_RTrim(@c_uccno9) IS NULL AND 
                   dbo.fnc_RTrim(@c_uccno10) IS NULL	
		BEGIN	
			SELECT 	PACKHEADER.PickSlipNo,  
			 	PACKDETAIL.LabelNo, 
				ORDERS.InvoiceNo, 
			 	ORDERS.ExternOrderKey, 
			 	PACKDETAIL.CartonNo, 
				ORDERS.Userdefine04, 
			 	ORDERS.C_Company, 
			 	ORDERS.C_Address1, 
			 	ORDERS.C_Address2, 
			 	ORDERS.C_Address3, 
			 	ORDERS.C_Address4, 
			 	PACKHEADER.Route, 
			 	ORDERS.C_Zip, 
-- 				MAX(IDS.Company) CompanyFrom,
-- 				MAX(IDS.Address1) Address1From,
-- 				MAX(IDS.Address2) Address2From,
-- 				MAX(IDS.Address3) Address3From,
				IDS.Company CompanyFrom,
				IDS.Address1 Address1From,
				IDS.Address2 Address2From,
				IDS.Address3 Address3From,
				CONVERT(CHAR(19), CONVERT(CHAR(10), GetDate(), 103) + ' ' + CONVERT(CHAR(8), GetDate(), 108)),
				'' as PriceLabel,
				SUBSTRING(ORDERS.Notes2, 1, 30) as Notes2,
                                Cartontype = CASE WHEN ORDERS.Type = 'D' THEN 'D'
                                             WHEN ORDERS.Type = 'R' THEN 'R'
                                             ELSE ''
                                             END 
			FROM ORDERS ORDERS (NOLOCK) 
		  		JOIN PACKHEADER (NOLOCK) ON (ORDERS.OrderKey = PACKHEADER.OrderKey)
		  		JOIN STORER (NOLOCK) ON (ORDERS.StorerKey = STORER.StorerKey) 
			  	JOIN PACKDETAIL (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)
		  		JOIN REPLENISHMENT (NOLOCK) ON REPLENISHMENT.RefNo = PACKDETAIL.RefNo
			  	LEFT OUTER JOIN STORER IDS (NOLOCK) ON (IDS.Storerkey = '11301')
		 	WHERE REPLENISHMENTGROUP = @c_batchno
			AND   REPLENISHMENT.TOLOC = 'PICK'
/*
	 		GROUP BY PACKHEADER.PickSlipNo, 
		  		PACKDETAIL.LabelNo,
				ORDERS.InvoiceNo, 
				ORDERS.ExternOrderKey, 
		  		PACKDETAIL.CartonNo, 
				ORDERS.Userdefine04, 
				ORDERS.C_Company, 
				ORDERS.C_Address1, 
				ORDERS.C_Address2, 
				ORDERS.C_Address3, 
				ORDERS.C_Address4, 
				PACKHEADER.Route, 
				ORDERS.C_Zip, 
				PACKHEADER.OrderKey,
				SUBSTRING(ORDERS.Notes2, 1, 30)
*/
  		END  
		ELSE
		BEGIN
			SELECT 	PACKHEADER.PickSlipNo,  
			 	PACKDETAIL.LabelNo, 
				ORDERS.InvoiceNo, 
			 	ORDERS.ExternOrderKey, 
			 	PACKDETAIL.CartonNo, 
				ORDERS.Userdefine04, 
			 	ORDERS.C_Company, 
			 	ORDERS.C_Address1, 
			 	ORDERS.C_Address2, 
			 	ORDERS.C_Address3, 
			 	ORDERS.C_Address4, 
			 	PACKHEADER.Route, 
			 	ORDERS.C_Zip, 
-- 				MAX(IDS.Company) CompanyFrom,
-- 				MAX(IDS.Address1) Address1From,
-- 				MAX(IDS.Address2) Address2From,
-- 				MAX(IDS.Address3) Address3From,
				IDS.Company CompanyFrom,
				IDS.Address1 Address1From,
				IDS.Address2 Address2From,
				IDS.Address3 Address3From,
				CONVERT(CHAR(19), CONVERT(CHAR(10), GetDate(), 103) + ' ' + CONVERT(CHAR(8), GetDate(), 108)),
				'' as PriceLabel,
				SUBSTRING(ORDERS.Notes2, 1, 30) as Notes2,
                                Cartontype = CASE WHEN ORDERS.Type = 'D' THEN 'D' /* FBR 34945 Added By Vicky */
                                             WHEN ORDERS.Type = 'R' THEN 'R'
                                             ELSE ''
                                             END 
			FROM ORDERS ORDERS (NOLOCK) 
		  		JOIN PACKHEADER (NOLOCK) ON (ORDERS.OrderKey = PACKHEADER.OrderKey)
		  		JOIN STORER (NOLOCK) ON (ORDERS.StorerKey = STORER.StorerKey) 
			  	JOIN PACKDETAIL (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)
		  		JOIN REPLENISHMENT (NOLOCK) ON REPLENISHMENT.RefNo = PACKDETAIL.RefNo
			  	LEFT OUTER JOIN STORER IDS (NOLOCK) ON (IDS.Storerkey = '11301')
		 	WHERE REPLENISHMENTGROUP = @c_batchno
			AND   REPLENISHMENT.TOLOC = 'PICK'
			AND ( REPLENISHMENT.RefNo = @c_uccno1 
			OR    REPLENISHMENT.RefNo = @c_uccno2
			OR    REPLENISHMENT.RefNo = @c_uccno3
     			OR    REPLENISHMENT.RefNo = @c_uccno4
			OR    REPLENISHMENT.RefNo = @c_uccno5
			OR    REPLENISHMENT.RefNo = @c_uccno6
			OR    REPLENISHMENT.RefNo = @c_uccno7 
			OR    REPLENISHMENT.RefNo = @c_uccno8
     			OR    REPLENISHMENT.RefNo = @c_uccno9
			OR    REPLENISHMENT.RefNo = @c_uccno10 )
/*
	 		GROUP BY PACKHEADER.PickSlipNo, 
		  		PACKDETAIL.LabelNo,
				ORDERS.InvoiceNo, 
				ORDERS.ExternOrderKey, 
		  		PACKDETAIL.CartonNo, 
				ORDERS.Userdefine04, 
				ORDERS.C_Company, 
				ORDERS.C_Address1, 
				ORDERS.C_Address2, 
				ORDERS.C_Address3, 
				ORDERS.C_Address4, 
				PACKHEADER.Route, 
				ORDERS.C_Zip, 
				PACKHEADER.OrderKey,
				SUBSTRING(ORDERS.Notes2, 1, 30)
*/
		END
	END 

END

GO