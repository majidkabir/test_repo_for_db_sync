SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


create view [dbo].[V_IDS_RCVSUM_001]
as
	select distinct convert(NVARCHAR(10), rtrim(upper(receipt.receiptkey))) as 'r_receiptkey',
				convert(NVARCHAR(20), rtrim(upper(receipt.externreceiptkey))) as 'r_externreceiptkey',
				convert(NVARCHAR(15), rtrim(upper(receipt.storerkey))) as 'r_storer',
				storer.company as 'r_company',
				receipt.receiptdate as 'r_receiptdate',
				convert(NVARCHAR(10), rtrim(upper(receipt.pokey))) as 'r_pokey',
				convert(NVARCHAR(15), rtrim(upper(receipt.carrierkey))) as 'r_carrierkey',
				receipt.carriername as 'r_carriername',
				receipt.carrieraddress1 as 'r_carrieraddress1',
				receipt.carrieraddress2 as 'r_carrieraddress2',
				convert(NVARCHAR(45), rtrim(upper(receipt.carriercity))) as 'r_carriercity',	
				receipt.carrierstate as 'r_carrierstate',
				receipt.carrierzip as 'r_carrierzip',
				receipt.carrierreference as 'r_carrierreference',
				receipt.warehousereference as 'r_warehousereference',
				receipt.origincountry as 'r_origincountry',
				code_cntry_orig.code_desc as 'r_origincountry_desc',
				receipt.destinationcountry as 'r_destinationcountry',
				code_cntry_dest.code_desc as 'r_destinationcountry_desc',
				receipt.vehiclenumber as 'r_vehiclenumber',
				code_vehicle.code_desc as 'r_vehiclenumber_desc',
				receipt.vehicledate as 'r_vehicledate',
				receipt.placeofloading as 'r_vehicleloading',
				receipt.placeofdischarge as 'r_placeofdischarge',
				receipt.placeofdelivery as 'r_placeofdelivery',
				receipt.termsnote as 'r_termsnote',
				code_termsnote.code_desc as 'r_termsnote_desc',
				convert(NVARCHAR(18), rtrim(upper(receipt.containerkey))) as 'r_containerkey',
				receipt.signatory as 'r_signatory',
				receipt.placeofissue as 'r_placeofissue',
				receipt.openqty as 'r_openqty',
				receipt.status as 'r_status',
				code_recstatus.code_desc as 'r_status_desc',
				replace(rtrim(convert(NVARCHAR(255), receipt.notes)), char(13), '') as 'r_notes',
				receipt.adddate as 'r_adddate',
				receipt.addwho as 'r_addwho',
				receipt.editdate as 'r_editdate',
				receipt.editwho as 'r_editwho',
				receipt.rectype as 'r_rectype',
				code_rectype.code_desc as 'r_rectype_desc',
				receipt.asnstatus as 'r_asnstatus',
				code_asnstatus.code_desc as 'r_asnstatus_desc',
				receipt.asnreason as 'r_asnreason',
				code_asnreason.code_desc as 'r_asnreason_desc',
				convert(NVARCHAR(5), rtrim(upper(receipt.facility))) as 'r_facility',
				facility.descr as 'r_facility_descr',
				convert(NVARCHAR(10), rtrim(upper(receipt.mbolkey))) as 'r_mbolkey',
				convert(NVARCHAR(10), rtrim(upper(receipt.appointment_no))) as 'r_appointment_no',
				convert(NVARCHAR(10), rtrim(upper(receipt.loadkey))) as 'r_loadkey',
				receipt.xdockflag as 'r_xdockflag',
				receipt.userdefine01 as 'r_userdefine01',

				convert(NVARCHAR(18), rtrim(upper(po.pokey))) as 'po_pokey',
				convert(NVARCHAR(20), rtrim(upper(po.externpokey))) as 'po_exterpokey',
				convert(NVARCHAR(15), rtrim(upper(po.storerkey))) as 'po_storerkey',
				po.podate as 'po_podate',
				po.sellersreference as 'po_sellersreference',
				po.buyersreference as 'po_buyersreference',
				po.otherreference as 'po_otherreference',
				po.potype as 'po_potype',
				code_potype.code_desc as 'po_potype_desc',
				po.sellername as 'po_sellername',
				po.selleraddress1 as 'po_selleraddress1',
				po.selleraddress2 as 'po_selleraddress2',
				po.selleraddress3 as 'po_selleraddress3',
				po.selleraddress4 as 'po_selleraddress4',
				po.sellercity as 'po_sellercity',
				po.sellerstate as 'po_sellerstate',
				po.sellerzip as 'po_sellerzip',
				po.sellerphone as 'po_sellerphone',
				po.sellervat as 'po_sellervat',
				po.buyername as 'po_buyername',
				po.buyeraddress1 as 'po_buyeraddress1',
				po.buyeraddress2 as 'po_buyeraddress2',
				po.buyeraddress3 as 'po_buyeraddress3',
				po.buyeraddress4 as 'po_buyeraddress4',
				po.buyercity as 'po_buyercity',
				po.buyerstate as 'po_buyerstate',
				po.buyerzip as 'po_buyerzip',
				po.buyerphone as 'po_buyerphone',
				po.buyervat as 'po_buyervat',
				po.origincountry as 'po_origincountry',
				code_pocntry_orig.code_desc as 'po_origincountry_desc',
				po.destinationcountry as 'po_destinationcountry',
				code_pocntry_dest.code_desc as 'po_destinationcountry_desc',
				po.vessel as 'po_vessel',
				po.vesseldate as 'po_vesseldate',
				po.placeofloading as 'po_placeofloading',
				po.placeofdischarge as 'po_placeofdischarge',
				po.placeofdelivery as 'po_placeofdelivery',
				po.pmtterm as 'po_pmtterm',
				code_pmtterm.code_desc as 'po_pmtterm_desc',
				po.transmethod as 'po_transmethod',
				code_transmethod.code_desc as 'po_transmethod_desc',
				po.termsnote as 'po_termsnote',
				code_po_termsnote.code_desc as 'po_termsnote_desc',
				po.signatory as 'po_signatory',
				po.placeofissue as 'po_placeofissue',
				po.openqty as 'po_openqty',
				po.status as 'po_status',
				code_status.code_desc as 'po_status_desc',
				replace(rtrim(convert(NVARCHAR(255), po.notes)), char(13), '') as 'po_notes',
				po.adddate as 'po_adddate',
				po.addwho as 'po_addwho',
				po.editdate as 'po_editdate',
				po.editwho as 'po_editwho',
				po.externstatus as 'po_externstatus',
				code_postage.code_desc as 'po_externstatus_desc',
				po.loadingdate as 'po_loadingdate',
				po.reasoncode as 'po_reasoncode',
				isnull(storerconfig.svalue, '0') as 'owitf'
	from receipt (nolock) 
	join storer (nolock)
		on receipt.storerkey = storer.storerkey
   left outer join receiptdetail (nolock) 
      on receipt.receiptkey = receiptdetail.receiptkey
	left outer join po (nolock)
		on receiptdetail.pokey = po.pokey
	left outer join facility (nolock)
		on receipt.facility = facility.facility
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'ISOCOUNTRY') as code_cntry_orig
		on receipt.origincountry = code_cntry_orig.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'ISOCOUNTRY') as code_cntry_dest
		on receipt.destinationcountry = code_cntry_dest.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'SALESCODE') as code_vehicle
		on receipt.vehiclenumber = code_vehicle.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'VESSELS') as code_termsnote
		on receipt.termsnote = code_termsnote.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'RECSTATUS') as code_recstatus
		on receipt.status = code_recstatus.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'RECTYPE') as code_rectype
		on receipt.rectype = code_rectype.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'ASNSTATUS') as code_asnstatus
		on receipt.asnstatus = code_asnstatus.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'RETREASON') as code_asnreason
		on receipt.asnreason = code_asnreason.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'QUANTITY') as code_uom
		on receiptdetail.uom = code_uom.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'ASNREASON') as code_condition
		on receiptdetail.conditioncode = code_condition.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'POTYPE') as code_potype
		on po.potype = code_potype.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'ISOCOUNTRY') as code_pocntry_orig
		on po.origincountry = code_pocntry_orig.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'ISOCOUNTRY') as code_pocntry_dest
		on po.destinationcountry = code_pocntry_dest.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'PMTTERM') as code_pmtterm
		on po.pmtterm = code_pmtterm.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'TRANSMETH') as code_transmethod
		on po.transmethod = code_transmethod.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'PMTTERM') as code_po_termsnote
		on po.termsnote = code_po_termsnote.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'POSTATUS') as code_status
		on po.status = code_status.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'POSTAGE') as code_postage
		on po.externstatus = code_postage.code
 	left outer join storerconfig (nolock) on receipt.storerkey = storerconfig.storerkey
      and configkey = 'OWITF'







GO