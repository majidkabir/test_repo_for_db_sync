SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


create view [dbo].[V_IDS_RCV_001]
as
	select convert(NVARCHAR(10), rtrim(upper(receipt.receiptkey))) as 'r_receiptkey',
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
				convert(NVARCHAR(5), rtrim(upper(receiptdetail.receiptlinenumber))) as 'rd_receiptlinenumber',
				convert(NVARCHAR(20), rtrim(upper(receiptdetail.externlineno))) as 'rd_externlineno',
				convert(NVARCHAR(15), rtrim(upper(receiptdetail.storerkey))) as 'rd_storerkey',
				convert(NVARCHAR(18), rtrim(upper(receiptdetail.pokey))) as 'rd_pokey',
				convert(NVARCHAR(20), rtrim(upper(receiptdetail.sku))) as 'rd_sku',
				convert(NVARCHAR(20), rtrim(upper(receiptdetail.altsku))) as 'rd_altsku',
				convert(NVARCHAR(18), rtrim(upper(receiptdetail.id))) as 'rd_id',
				receiptdetail.status as 'rd_status',
				receiptdetail.datereceived as 'rd_datereceived',
				receiptdetail.qtyexpected as 'rd_qtyexpected',
				receiptdetail.qtyadjusted as 'rd_qtyadjusted',
				receiptdetail.qtyreceived as 'rd_qtyreceived',
				receiptdetail.uom as 'rd_uom',
				code_uom.code_desc as 'rd_uom_desc',
				convert(NVARCHAR(18), rtrim(upper(receiptdetail.vesselkey))) as 'rd_vesselkey',
				convert(NVARCHAR(18), rtrim(upper(receiptdetail.voyagekey))) as 'rd_voyagekey',
				convert(NVARCHAR(18), rtrim(upper(receiptdetail.xdockkey))) as 'rd_xdockkey',
				convert(NVARCHAR(18), rtrim(upper(receiptdetail.containerkey))) as 'rd_containerkey',
				convert(NVARCHAR(10), rtrim(upper(receiptdetail.toloc))) as 'rd_toloc',
				convert(NVARCHAR(10), rtrim(upper(receiptdetail.tolot))) as 'rd_tolot',
				convert(NVARCHAR(18), rtrim(upper(receiptdetail.toid))) as 'rd_toid',
				convert(NVARCHAR(10), rtrim(upper(receiptdetail.conditioncode))) as 'rd_conditioncode',
				code_condition.code_desc as 'rd_conditioncode_desc',
				sku.lottable01label as 'rd_l1_label',
				code_lottable01.code_desc as 'rd_l1_label_desc',
				receiptdetail.lottable01 as 'rd_l1',
				sku.lottable02label as 'rd_l2_label',
				code_lottable02.code_desc as 'rd_l2_label_desc',
				receiptdetail.lottable02 as 'rd_l2',
				sku.lottable03label as 'rd_l3_label',
				code_lottable03.code_desc as 'rd_l3_label_desc',
				receiptdetail.lottable03 as 'rd_l3',
				sku.lottable04label as 'rd_l4_label',
				code_lottable04.code_desc as 'rd_l4_label_desc',
				receiptdetail.lottable04 as 'rd_l4',
				sku.lottable05label as 'rd_l5_label',
				code_lottable05.code_desc as 'rd_l5_label_desc',
				receiptdetail.lottable05 as 'rd_l5',
				receiptdetail.casecnt as 'rd_casecnt',
				receiptdetail.innerpack as 'rd_innerpack',
				receiptdetail.pallet as 'rd_pallet',
				receiptdetail.cube as 'rd_cube',
				receiptdetail.grosswgt as 'rd_grosswgt',
				receiptdetail.netwgt as 'rd_netwgt',
				pack.packuom3 as 'cc_master unit',
				code_uom3.code_desc as 'cc_master_unit_desc',
				pack.qty as 'cc_mu_units',
				pack.packuom2 as 'cc_inner uom',
				code_uom2.code_desc as 'cc_inner_uom_desc',
				pack.innerpack as 'cc_inner_uom_qty',
				pack.packuom1 as 'cc_case_uom',
				code_uom1.code_desc as 'cc_case_uom_desc',
				pack.casecnt as 'cc_case_uom_qty',
				pack.packuom4 as 'cc_pl_uom',
				code_uom4.code_desc as 'cc_pl_uom_desc',
				pack.pallet as 'cc_pl_uom_qty',
				pack.palletti as 'cc_units_per_layer',
				pack.pallethi as 'cc_layers_per_pl',
				receiptdetail.unitprice as 'rd_unitprice',
				receiptdetail.adddate as 'rd_adddate',
				receiptdetail.addwho as 'rd_addwho',
				receiptdetail.editdate as 'rd_editdate',
				receiptdetail.editwho as 'rd_editwho',
				convert(NVARCHAR(10), rtrim(upper(receiptdetail.subreasoncode))) as 'rd_subreasoncode',
				code_subreason.code_desc as 'rd_subreasoncode_desc',
				convert(NVARCHAR(10), rtrim(upper(receiptdetail.putawayloc))) as 'rd_putawayloc',
				convert(NVARCHAR(5), rtrim(upper(receiptdetail.polinenumber))) as 'rd_polinenumber',
				convert(NVARCHAR(10), rtrim(upper(receiptdetail.loadkey))) as 'rd_loadkey',
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
				convert(NVARCHAR(5), rtrim(upper(podetail.polinenumber))) as 'pod_polinenumber',
				convert(NVARCHAR(10), rtrim(upper(podetail.podetailkey))) as 'pod_podetailkey',
				convert(NVARCHAR(20), rtrim(upper(podetail.externpokey))) as 'pod_externpokey',
				convert(NVARCHAR(20), rtrim(upper(podetail.externlineno))) as 'pod_externlineno',
				podetail.markscontainer as 'pod_markscontainer',
				convert(NVARCHAR(20), rtrim(upper(podetail.sku))) as 'pod_sku',
				podetail.skudescription as 'pod_skudescription',
				convert(NVARCHAR(20), rtrim(upper(podetail.manufacturersku))) as 'pod_manufacturersku',
				convert(NVARCHAR(20), rtrim(upper(podetail.retailsku))) as 'pod_retailsku',
				convert(NVARCHAR(20), rtrim(upper(podetail.altsku))) as 'pod_altsku',
				podetail.qtyordered as 'pod_qtyordered',
				podetail.qtyadjusted as 'pod_qtyadjusted',
				podetail.qtyreceived as 'pod_qtyreceived',
				podetail.unitprice as 'pod_unitprice',
				podetail.uom as 'pod_uom',
				code_pod_uom.code_desc as 'pod_uom_desc',
				replace(rtrim(convert(NVARCHAR(255), podetail.notes)), char(13), '') as 'pod_notes',
				podetail.adddate as 'pod_adddate',
				podetail.addwho as 'pod_addwho',
				podetail.editdate as 'pod_editdate',
				podetail.editwho as 'pod_editwho',
				podetail.polinestatus as 'pod_polinestatus',
				convert(NVARCHAR(5), rtrim(upper(podetail.facility))) as 'pod_facility',
				convert(NVARCHAR(20), rtrim(upper(sku.manufacturersku))) as'sku_manufacturersku',
				convert(NVARCHAR(20), rtrim(upper(sku.retailsku))) as 'sku_retailsku',
				convert(NVARCHAR(20), rtrim(upper(sku.altsku))) as 'sku_altsku',
				sku.descr as 'sku_descr',
				(sku.busr1 + sku.busr2) as 'sku_second_lang_descr',
				sku.cost as 'sku_cost',
				sku.price as 'sku_price',
				convert(NVARCHAR(18), rtrim(upper(sku.susr3))) as 'sku_principal',
				code_principal.code_desc as 'sku_principal_desc',
				convert(NVARCHAR(30), rtrim(upper(sku.busr10))) as 'sku_gdsstorerkey',
				isnull(storerconfig.svalue, '0') as 'owitf'
	from receipt (nolock) join receiptdetail (nolock)
		on receipt.receiptkey = receiptdetail.receiptkey
	join sku (nolock)
		on receiptdetail.storerkey = sku.storerkey
			and receiptdetail.sku = sku.sku
	join storer (nolock)
		on receipt.storerkey = storer.storerkey
	left outer join po (nolock)
		on receiptdetail.pokey = po.pokey
	left outer join podetail (nolock)
		on receiptdetail.pokey = podetail.pokey
			and receiptdetail.polinenumber = podetail.polinenumber
	left outer join facility (nolock)
		on receipt.facility = facility.facility
	left outer join pack (nolock)
		on receiptdetail.packkey = pack.packkey
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
						  where listname = 'LOTTABLE01') as code_lottable01
		on sku.lottable01label = code_lottable01.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'LOTTABLE02') as code_lottable02
		on sku.lottable02label = code_lottable02.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'LOTTABLE03') as code_lottable03
		on sku.lottable03label = code_lottable03.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'LOTTABLE04') as code_lottable04
		on sku.lottable04label = code_lottable04.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'LOTTABLE05') as code_lottable05
		on sku.lottable05label = code_lottable05.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'ASNSUBRSN') as code_subreason
		on receiptdetail.subreasoncode = code_subreason.code
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
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'QUANTITY') as code_pod_uom
		on podetail.uom = code_pod_uom.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'QUANTITY') as code_uom1
		on pack.packuom1 = code_uom1.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'QUANTITY') as code_uom2
		on pack.packuom2 = code_uom2.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'QUANTITY') as code_uom3
		on pack.packuom3 = code_uom3.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'QUANTITY') as code_uom4
		on pack.packuom4 = code_uom4.code
	left outer join (select code, description as 'code_desc'
						  from codelkup (nolock)
						  where listname = 'PRINCIPAL') as code_principal
		on sku.susr3 = code_principal.code
 	left outer join storerconfig (nolock)
 		on receipt.storerkey = storerconfig.storerkey
			and configkey = 'OWITF'





GO